from flask import Flask
from flask_cors import CORS

from api.v1.endpoints import api_v1

app = Flask(__name__)
CORS(app)

app.register_blueprint(api_v1, url_prefix="/api/v1")

if __name__ == "__main__":
    app.run(debug=True)
