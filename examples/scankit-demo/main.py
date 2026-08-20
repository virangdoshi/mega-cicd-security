from flask import Flask
import hashlib

app = Flask(__name__)

# Demo: weak pattern for SAST demos (do not use in production)
SECRET = "hardcoded-demo-key"

@app.route("/")
def hello():
    return {"status": "ok", "hash": hashlib.md5(b"demo").hexdigest()}

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
