from flask import Flask, jsonify, abort, request

# Data for the API
days = [
    {"id": 1, "name": "Monday"},
    {"id": 2, "name": "Tuesday"},
    {"id": 3, "name": "Wednesday"},
    {"id": 4, "name": "Thursday"},
    {"id": 5, "name": "Friday"},
    {"id": 6, "name": "Saturday"},
    {"id": 7, "name": "Sunday"},
]

# Initialize the Flask app
app = Flask(__name__)

# Endpoint to get all days
@app.route("/", methods=["GET"])
def get_days():
    return jsonify(days)

# Endpoint to get a specific day by ID
@app.route("/<int:day_id>", methods=["GET"])
def get_day(day_id):
    day = [day for day in days if day["id"] == day_id]
    if len(day) == 0:
        abort(404, description="Day not found")
    return jsonify({"day": day[0]})

# Endpoint to add a new day (POST)
@app.route("/", methods=["POST"])
def post_days():
    if not request.json or "name" not in request.json:
        abort(400, description="Missing 'name' in request")
    new_day = {"id": len(days) + 1, "name": request.json["name"]}
    days.append(new_day)
    return jsonify({"success": True, "day": new_day}), 201

# Health check endpoint
@app.route("/health", methods=["GET"])
def health_check():
    return jsonify({"status": "healthy"}), 200

# Custom error handler for 404
@app.errorhandler(404)
def not_found(error):
    return jsonify({"error": error.description}), 404

# Custom error handler for 400
@app.errorhandler(400)
def bad_request(error):
    return jsonify({"error": error.description}), 400

# Main entry point for the app
import os

if __name__ == "__main__":
    debug = os.getenv("FLASK_DEBUG", "false").lower() == "true"
    app.run(debug=debug, host="0.0.0.0", port=5000)
