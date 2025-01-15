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
from PIL import Image
import torch
from ultralytics import YOLO

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
    print(f"Body: {request.get_data().decode('utf-8')}")

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
@jwt_required()  # Hanya bisa diakses oleh pengguna dengan akses JWT
def add_user():
    current_user = get_jwt_identity()
    if current_user['role'] not in ['admin', 'pemilik']:
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

        # Create identity dictionary
        identity = {
            'user_id': user_id,
            'username': db_username,
            'nama_lengkap': nama_lengkap,
            'role': role
        }

        access_token = create_access_token(identity=identity)
        
        return jsonify({
            "access_token": access_token,
            "nama_lengkap": nama_lengkap,
            "role": role
        }), 200
    except Exception as e:
        return jsonify({"message": f"Error: {str(e)}"}), 500
    finally:
        cur.close()
    
@app.route("/detect_damage", methods=["POST"])
@jwt_required()  # Menambahkan proteksi JWT
def detect_damage():
    try:
        # Get current user from JWT
        current_user = get_jwt_identity()
        
        if "file" not in request.files:
            return jsonify({"error": "Mohon masukkan file gambar"}), 400

        file = request.files["file"]
        image = Image.open(file)

        start_time = time.time()
        results = model(image)
        
        damages = {}
        for result in results[0].boxes.data.tolist():
            x1, y1, x2, y2, confidence, class_id = result
            damage_type = DAMAGE_LABELS[int(class_id)]
            
            if float(confidence) < 0.5:
                continue

            if damage_type not in damages or float(confidence) > float(damages[damage_type]['confidence'].replace('%', '')):
                damages[damage_type] = {
                    "tipe_kerusakan": damage_type,
                    "tingkat_keparahan": SEVERITY_MAPPING[damage_type],
                    "bbox": [float(x1), float(y1), float(x2), float(y2)],
                    "confidence": f"{float(confidence):.2%}"
                }

        damages_list = list(damages.values())
        duration = time.time() - start_time

        rendered_image = results[0].plot()
        buffered = io.BytesIO()
        Image.fromarray(rendered_image).save(buffered, format="JPEG")
        img_str = base64.b64encode(buffered.getvalue()).decode()

        response = {
            "status": "success",
            "waktu_proses": f"{duration:.4f}s",
            "jumlah_kerusakan": len(damages_list),
            "daftar_kerusakan": damages_list if damages_list else [{
                "tipe_kerusakan": "Tidak terdeteksi",
                "tingkat_keparahan": "Model kurang yakin memprediksi",
                "confidence": "0%"
            }],
            "gambar_hasil": img_str
        }

        return jsonify(response)

    except Exception as e:
        return jsonify({
            "status": "error",
            "pesan": str(e)
        }), 500
        
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