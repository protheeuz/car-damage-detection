# from werkzeug.security import generate_password_hash

# password = "admin1"
# hashed_password = generate_password_hash(password)
# print(hashed_password)
from werkzeug.security import check_password_hash

hashed_password = "pbkdf2:sha256:600000$czzwtgCqo0e9XJcl$846c18ea45872eb0903c614857315f3d871446170b5a944ac409e030d091ba5c"
password = "admin1"

if check_password_hash(hashed_password, password):
    print("Password cocok!")
else:
    print("Password tidak cocok!")