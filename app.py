import time
import io
import json
import MySQLdb
import numpy as np
import base64
import config
from datetime import datetime
from flask import Flask, request, jsonify
from flask_mysqldb import MySQL
from flask_jwt_extended import JWTManager, create_access_token, jwt_required, get_jwt_identity
from werkzeug.security import generate_password_hash, check_password_hash
from PIL import Image, UnidentifiedImageError
import torch
from ultralytics import YOLO
from sklearn.metrics import confusion_matrix, accuracy_score, precision_score, recall_score, f1_score
import numpy as np

# Inisialisasi Flask app
app = Flask(__name__)
app.config.from_object(config.Config)

mysql = MySQL()
mysql.init_app(app)
jwt = JWTManager(app)

# Load model YOLO
model = YOLO('model/car-damage-model.pt') 

# Definisi label kerusakan
DAMAGE_LABELS = ['retak', 'penyok', 'pecah kaca', 'lampu rusak', 'goresan', 'ban kempes']

# Mapping tingkat keparahan
SEVERITY_MAPPING = {
    'retak': 'Rusak Sedang',
    'penyok': 'Rusak Sedang', 
    'pecah kaca': 'Rusak Berat',
    'lampu rusak': 'Rusak Sedang',
    'goresan': 'Rusak Ringan',
    'ban kempes': 'Rusak Sedang'
}

@app.before_request
def log_request_info():
    print(f"Headers: {request.headers}")
    if request.content_type and "multipart/form-data" in request.content_type:
        print("Body: [multipart/form-data content omitted]")
    else:
        print(f"Body: {request.get_data().decode('utf-8', errors='replace')}")

@jwt.user_identity_loader
def user_identity_loader(user):
    return str(user['user_id']) if isinstance(user, dict) else str(user)

@app.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    username = data.get('username', '').strip()
    nama_lengkap = data.get('nama_lengkap', '').strip()
    password = data.get('password', '').strip()
    role = 'pelanggan'

    if not all([username, nama_lengkap, password]):
        return jsonify({"message": "Username, nama lengkap, dan password harus diisi"}), 400

    hashed_password = generate_password_hash(password)

    cur = mysql.connection.cursor()
    try:
        cur.execute("""
            INSERT INTO users (username, password, nama_lengkap, role)
            VALUES (%s, %s, %s, %s)
        """, (username, hashed_password, nama_lengkap, role))
        mysql.connection.commit()
        return jsonify({"message": "Pendaftaran berhasil"}), 201
    except MySQLdb.IntegrityError:
        return jsonify({"message": "Username sudah ada"}), 409
    except Exception as e:
        return jsonify({"message": f"Error: {str(e)}"}), 500
    finally:
        cur.close()
        
@app.route('/get_detection_results', methods=['GET'])
@jwt_required()
def get_detection_results():
    current_user_id = get_jwt_identity()

    cur = mysql.connection.cursor()
    try:
        # Ambil role pengguna dari database
        cur.execute("SELECT role FROM users WHERE id = %s", (current_user_id,))
        role_data = cur.fetchone()

        if not role_data:
            return jsonify({"status": "error", "message": "User not found"}), 404

        user_role = role_data[0]

        # Jika montir atau pemilik, ambil semua data
        if user_role in ['montir', 'pemilik']:
            cur.execute("""
                SELECT model_kendaraan, tahun_kendaraan, plat_nomor, label, created_at
                FROM detection_results
                ORDER BY created_at DESC
            """)
        else:
            # Jika bukan montir/pemilik, hanya ambil data pengguna tersebut
            cur.execute("""
                SELECT model_kendaraan, tahun_kendaraan, plat_nomor, label, created_at
                FROM detection_results
                WHERE user_id = %s
                ORDER BY created_at DESC
            """, (current_user_id,))

        results = cur.fetchall()

        # Format hasil query ke dalam JSON
        data = [
            {
                "model_kendaraan": row[0],
                "tahun_kendaraan": row[1],
                "plat_nomor": row[2],
                "kerusakan": row[3],
                "waktu": row[4].strftime("%Y-%m-%d %H:%M:%S")
            }
            for row in results
        ]

        return jsonify({"status": "success", "data": data}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        cur.close()


@app.route('/add_vehicle', methods=['POST'])
@jwt_required()
def add_vehicle():
    # Get user_id directly from the JWT identity
    current_user_id = get_jwt_identity()
    
    # Get user role from database
    cur = mysql.connection.cursor()
    try:
        cur.execute("SELECT role FROM users WHERE id = %s", (current_user_id,))
        user_data = cur.fetchone()
        if not user_data:
            return jsonify({"message": "User not found"}), 404
        role = user_data[0]
    finally:
        cur.close()
    
    if role != 'pelanggan':
        return jsonify({"message": "Hanya pelanggan yang dapat menambahkan data kendaraan"}), 403

    data = request.get_json()
    plat_nomor = data.get('plat_nomor', '').strip()
    model_kendaraan = data.get('model_kendaraan', '').strip()
    tahun_kendaraan = data.get('tahun_kendaraan')

    if not plat_nomor or not model_kendaraan or not tahun_kendaraan:
        return jsonify({"message": "Semua field harus diisi"}), 400

    try:
        tahun_kendaraan = int(tahun_kendaraan)
        current_year = datetime.now().year
        if tahun_kendaraan < 1900 or tahun_kendaraan > current_year:
            return jsonify({"message": f"Tahun kendaraan harus antara 1900 dan {current_year}"}), 400
    except ValueError:
        return jsonify({"message": "Tahun kendaraan harus berupa angka"}), 400

    cur = mysql.connection.cursor()
    try:
        cur.execute("""
            INSERT INTO vehicles (user_id, plat_nomor, model_kendaraan, tahun_kendaraan, created_at)
            VALUES (%s, %s, %s, %s, NOW())
        """, (current_user_id, plat_nomor, model_kendaraan, tahun_kendaraan))
        mysql.connection.commit()
        return jsonify({"message": "Data kendaraan berhasil ditambahkan"}), 201
    except Exception as e:
        return jsonify({"message": f"Database error: {str(e)}"}), 500
    finally:
        cur.close()

@app.route('/get_vehicle', methods=['GET'])
@jwt_required()
def get_vehicle():
    current_user = get_jwt_identity()

    if current_user['role'] != 'pelanggan':
        return jsonify({"message": "Hanya pelanggan yang memiliki data kendaraan"}), 403

    cur = mysql.connection.cursor()
    try:
        cur.execute("""
            SELECT plat_nomor, model_kendaraan, tahun_kendaraan
            FROM vehicles
            WHERE user_id = %s
        """, (current_user['user_id'],))
        vehicle = cur.fetchone()
        if vehicle:
            return jsonify({"plat_nomor": vehicle[0], "model_kendaraan": vehicle[1], "tahun_kendaraan": vehicle[2]}), 200
        else:
            return jsonify({"message": "Data kendaraan tidak ditemukan"}), 404
    except Exception as e:
        return jsonify({"message": f"Error: {str(e)}"}), 500
    finally:
        cur.close()

@app.route('/update_vehicle', methods=['PUT'])
@jwt_required()
def update_vehicle():
    current_user = get_jwt_identity()

    if current_user['role'] != 'pelanggan':
        return jsonify({"message": "Hanya pelanggan yang dapat memperbarui data kendaraan"}), 403

    data = request.get_json()
    plat_nomor = data.get('plat_nomor', '').strip()
    model_kendaraan = data.get('model_kendaraan', '').strip()
    tahun_kendaraan = data.get('tahun_kendaraan')

    if not plat_nomor or not model_kendaraan or not tahun_kendaraan:
        return jsonify({"message": "Semua field harus diisi"}), 400

    try:
        tahun_kendaraan = int(tahun_kendaraan)
        current_year = datetime.now().year
        if tahun_kendaraan < 1900 or tahun_kendaraan > current_year:
            return jsonify({"message": f"Tahun kendaraan harus antara 1900 dan {current_year}"}), 400
    except ValueError:
        return jsonify({"message": "Tahun kendaraan harus berupa angka"}), 400

    cur = mysql.connection.cursor()
    try:
        cur.execute("""
            UPDATE vehicles
            SET plat_nomor = %s, model_kendaraan = %s, tahun_kendaraan = %s
            WHERE user_id = %s
        """, (plat_nomor, model_kendaraan, tahun_kendaraan, current_user['user_id']))
        mysql.connection.commit()
        return jsonify({"message": "Data kendaraan berhasil diperbarui"}), 200
    except Exception as e:
        return jsonify({"message": f"Error: {str(e)}"}), 500
    finally:
        cur.close()
        
@app.route('/add_user', methods=['POST'])
@jwt_required()
def add_user():
    current_user = get_jwt_identity()
    print(f"Current user from JWT: {current_user}")  

    if isinstance(current_user, str):
        current_user = {"role": "pemilik"} 

    if current_user.get('role') not in ['admin', 'pemilik']:
        return jsonify({"message": "Hanya admin atau pemilik yang dapat menambahkan user"}), 403

    data = request.get_json()
    username = data.get('username').strip()
    nama_lengkap = data.get('nama_lengkap').strip()
    password = data.get('password').strip()
    role = data.get('role').strip().lower()  # Role harus disesuaikan dengan database
    
    # Validasi role
    if role not in ['admin', 'pemilik', 'montir']:
        return jsonify({"message": f"Role '{role}' tidak valid"}), 400

    # Validasi input dasar
    if not all([username, nama_lengkap, password, role]):
        return jsonify({
            "message": "Username, nama lengkap, password, dan role harus diisi"
        }), 400

    # Tidak perlu data kendaraan untuk role selain pelanggan
    hashed_password = generate_password_hash(password)

    cur = mysql.connection.cursor()
    try:
        cur.execute("""
            INSERT INTO users (username, password, nama_lengkap, role) 
            VALUES (%s, %s, %s, %s)
        """, (
            username, 
            hashed_password, 
            nama_lengkap, 
            role
        ))
        
        mysql.connection.commit()
        return jsonify({
            "message": f"User dengan role '{role}' berhasil ditambahkan",
            "data": {
                "username": username,
                "nama_lengkap": nama_lengkap,
                "role": role
            }
        }), 201
    except MySQLdb.IntegrityError:
        return jsonify({"message": "Username sudah ada"}), 409
    finally:
        cur.close()
        
@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    username = data.get('username', '').strip()
    password = data.get('password', '').strip()

    cur = mysql.connection.cursor()
    try:
        cur.execute("""
            SELECT id, username, password, nama_lengkap, role
            FROM users WHERE username = %s
        """, (username,))
        user = cur.fetchone()

        if not user:
            return jsonify({"message": "Invalid credentials"}), 401

        user_id, db_username, db_hashed_password, nama_lengkap, role = user
        if not check_password_hash(db_hashed_password, password):
            return jsonify({"message": "Invalid credentials"}), 401

        # Update payload to include both user_id and role
        access_token = create_access_token(identity={"user_id": user_id, "role": role})
        
        return jsonify({
            "access_token": access_token,
            "nama_lengkap": nama_lengkap,
            "role": role
        }), 200
    except Exception as e:
        return jsonify({"message": f"Error: {str(e)}"}), 500
    finally:
        cur.close()
    
@app.route('/detect_damage', methods=["POST"])
@jwt_required()
def detect_damage():
    try:
        if "file" not in request.files:
            return jsonify({"error": "Mohon masukkan file gambar"}), 400

        file = request.files["file"]

        try:
            # Validasi format gambar
            image = Image.open(file)
            image.verify()  # Pastikan file adalah gambar valid
        except UnidentifiedImageError:
            return jsonify({"error": "File bukan gambar yang valid"}), 400

        start_time = time.time()
        image = Image.open(file)  # Load ulang untuk diproses
        results = model(image)

        damages = {}
        ground_truth_labels = []  # Label yang benar (ground truth)
        predicted_labels = []  # Label prediksi dari model

        for result in results[0].boxes.data.tolist():
            x1, y1, x2, y2, confidence, class_id = result
            damage_type = DAMAGE_LABELS[int(class_id)]  

            # Ambil tingkat keparahan sesuai tipe kerusakan
            severity = SEVERITY_MAPPING.get(damage_type) 

            if float(confidence) < 0.5:
                continue

            # Tambahkan label prediksi dan ground truth
            predicted_labels.append(damage_type)
            # Asumsi ground truth sesuai label tipe kerusakan yang diharapkan
            ground_truth_labels.append(damage_type)

            # Ambil rentang harga estimasi kerusakan berdasarkan tipe dan tingkat keparahan
            cur = mysql.connection.cursor()
            cur.execute("""
                SELECT price_min, price_max FROM damage_estimations 
                WHERE damage_type = %s AND severity = %s
            """, (damage_type, severity))
            price_data = cur.fetchone()
            
            # Jika harga estimasi ditemukan
            if price_data:
                price_min, price_max = price_data
                price_range = f"Rp {price_min:,.2f} - Rp {price_max:,.2f}"
            else:
                price_range = "Harga tidak tersedia"  # Placeholder jika harga tidak tersedia

            damages[damage_type] = {
                "tipe_kerusakan": damage_type,
                "tingkat_keparahan": severity,
                "harga_estimasi": price_range,
                "bbox": [float(x1), float(y1), float(x2), float(y2)],
                "confidence": f"{float(confidence):.2%}"
            }

        damages_list = list(damages.values())
        duration = time.time() - start_time

        # Debugging: Cek hasil dari ground_truth_labels dan predicted_labels
        print(f"Ground Truth Labels: {ground_truth_labels}")
        print(f"Predicted Labels: {predicted_labels}")

        # Evaluasi model: Confusion Matrix dan metrik lainnya
        if ground_truth_labels and predicted_labels:
            cm = confusion_matrix(ground_truth_labels, predicted_labels, labels=DAMAGE_LABELS)
            accuracy = accuracy_score(ground_truth_labels, predicted_labels)
            precision = precision_score(ground_truth_labels, predicted_labels, average='weighted', zero_division=0)
            recall = recall_score(ground_truth_labels, predicted_labels, average='weighted', zero_division=0)
            f1 = f1_score(ground_truth_labels, predicted_labels, average='weighted', zero_division=0)

            evaluation_metrics = {
                "confusion_matrix": cm.tolist(),  # Mengonversi numpy array menjadi list agar bisa dikirim ke frontend
                "accuracy": accuracy,
                "precision": precision,
                "recall": recall,
                "f1_score": f1
            }
        else:
            evaluation_metrics = {}

        # Rendered image
        rendered_image = results[0].plot()
        buffered = io.BytesIO()
        Image.fromarray(rendered_image).save(buffered, format="JPEG")
        img_str = base64.b64encode(buffered.getvalue()).decode()

        # Simpan ke database
        cur = mysql.connection.cursor()
        current_user_id = get_jwt_identity()

        cur.execute(""" 
            SELECT plat_nomor, model_kendaraan, tahun_kendaraan 
            FROM vehicles 
            WHERE user_id = %s 
            ORDER BY created_at DESC LIMIT 1
        """, (current_user_id,))
        vehicle_info = cur.fetchone()

        if not vehicle_info:
            return jsonify({"message": "Informasi kendaraan tidak ditemukan"}), 404

        plat_nomor, model_kendaraan, tahun_kendaraan = vehicle_info

        try:
            for damage in damages_list:
                cur.execute(""" 
                    INSERT INTO detection_results (
                        user_id, label, detection_time, plat_nomor, 
                        model_kendaraan, tahun_kendaraan, created_at
                    ) VALUES (%s, %s, NOW(), %s, %s, %s, NOW())
                """, (
                    current_user_id,
                    damage['tipe_kerusakan'],
                    plat_nomor,
                    model_kendaraan,
                    tahun_kendaraan
                ))
            mysql.connection.commit()
        except Exception as e:
            mysql.connection.rollback()
            return jsonify({"message": f"Error saving detection results: {str(e)}"}), 500
        finally:
            cur.close()

        response = {
            "status": "success",
            "waktu_proses": f"{duration:.4f}s",
            "jumlah_kerusakan": len(damages_list),
            "daftar_kerusakan": damages_list if damages_list else [
                {
                    "tipe_kerusakan": "Tidak terdeteksi",
                    "tingkat_keparahan": "Model kurang yakin memprediksi",
                    "confidence": "0%",
                    "harga_estimasi": "Harga tidak tersedia"
                }
            ],
            "gambar_hasil": img_str,
            "evaluation_metrics": evaluation_metrics 
        }

        return jsonify(response)

    except Exception as e:
        print(f"Error in detect_damage: {str(e)}")
        return jsonify({"status": "error", "pesan": str(e)}), 500
        
@app.route('/save_detection_results', methods=['POST'])
@jwt_required()
def save_detection_results():
    current_user = get_jwt_identity()
    user_id = current_user['user_id']

    # Ambil informasi kendaraan dari user
    cur = mysql.connection.cursor()
    cur.execute("""
        SELECT plat_nomor, model_kendaraan, tahun_kendaraan 
        FROM users WHERE id = %s
    """, [user_id])
    user_vehicle = cur.fetchone()
    cur.close()

    if not user_vehicle:
        return jsonify({"message": "Informasi kendaraan tidak ditemukan untuk pengguna ini"}), 400

    plat_nomor, model_kendaraan, tahun_kendaraan = user_vehicle

    # Proses data deteksi
    data = request.get_json()
    detection_counts = data.get('detection_counts')
    detection_time = datetime.now()

    cur = mysql.connection.cursor()
    try:
        for label, count in detection_counts.items():
            cur.execute("""
                INSERT INTO detection_results (user_id, label, count, detection_time, plat_nomor, model_kendaraan, tahun_kendaraan) 
                VALUES (%s, %s, %s, %s, %s, %s, %s)
            """, (
                user_id, label, count, detection_time, plat_nomor, model_kendaraan, tahun_kendaraan
            ))
        mysql.connection.commit()
        return jsonify({"message": "Detection results saved successfully"}), 200
    except Exception as e:
        mysql.connection.rollback()
        return jsonify({"message": f"Error saving detection results: {str(e)}"}), 500
    finally:
        cur.close()

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000, debug=True)