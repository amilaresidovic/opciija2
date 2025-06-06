from flask import Flask, jsonify, request
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
import os
import time
from sqlalchemy.exc import OperationalError
from sqlalchemy import text

app = Flask(__name__)
CORS(app)


app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('DATABASE_URL', 'postgresql://postgres:postgres@localhost:5432/app_db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)

class Contact(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    first_name = db.Column(db.String(80), nullable=False)
    last_name = db.Column(db.String(80), nullable=False)
    email = db.Column(db.String(120), nullable=False)
    
    def to_json(self):
        return {
            "id": self.id,
            "firstName": self.first_name,
            "lastName": self.last_name,
            "email": self.email
        }

def wait_for_db():
    retries = 10
    while retries > 0:
        try:
            with app.app_context():
                db.session.execute(text('SELECT 1'))
            print("Database connected successfully!")
            return True
        except OperationalError as e:
            retries -= 1
            print(f"Waiting for database... retries left: {retries}, error: {e}")
            time.sleep(5)
    
    print("Could not connect to database after multiple attempts")
    return False

@app.route('/api/health')
def health_check():
    try:
        db.session.execute(text('SELECT 1'))
        return jsonify({
            "status": "healthy", 
            "database": "connected",
            "service": "backend"
        }), 200
    except Exception as e:
        print(f"Health check failed: {e}")
        return jsonify({
            "status": "unhealthy", 
            "error": str(e),
            "service": "backend"
        }), 500

@app.route('/api/contacts', methods=['GET'])
def get_contacts():
    try:
        contacts = Contact.query.all()
        return jsonify({"contacts": [c.to_json() for c in contacts]})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/create_contact', methods=['POST'])
def create_contact():
    try:
        data = request.get_json()
        if not data or not all(key in data for key in ['firstName', 'lastName', 'email']):
            return jsonify({"message": "Missing required fields"}), 400
        
        new_contact = Contact(
            first_name=data['firstName'],
            last_name=data['lastName'],
            email=data['email']
        )
        db.session.add(new_contact)
        db.session.commit()

        return jsonify({
            "message": "Contact created!", 
            "contact": new_contact.to_json()
        }), 201

    except Exception as e:
        db.session.rollback()
        return jsonify({"message": str(e)}), 400

@app.route('/api/delete_contact/<int:id>', methods=['DELETE'])
def delete_contact(id):
    try:
        contact = Contact.query.get(id)
        if not contact:
            return jsonify({"message": "Contact not found"}), 404

        db.session.delete(contact)
        db.session.commit()
        return jsonify({"message": "Contact deleted successfully"}), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({"message": str(e)}), 400

@app.route('/api/update_contact/<int:id>', methods=['PATCH'])
def update_contact(id):
    try:
        data = request.get_json()
        contact = Contact.query.get(id)
        if not contact:
            return jsonify({"message": "Contact not found"}), 404

        if 'firstName' in data:
            contact.first_name = data['firstName']
        if 'lastName' in data:
            contact.last_name = data['lastName']
        if 'email' in data:
            contact.email = data['email']

        db.session.commit()
        return jsonify({
            "message": "Contact updated successfully",
            "contact": contact.to_json()
        }), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({"message": str(e)}), 400

@app.route('/')
def home():
    return jsonify({"message": "Backend API is running", "status": "ok"})

def init_db():
    try:
        if wait_for_db():
            with app.app_context():
                db.create_all()
                print("Database tables created successfully!")
        else:
            print("Failed to initialize database")
    except Exception as e:
        print(f"Database initialization error: {e}")

if __name__ == "__main__":
    init_db()
    print("Starting Flask application...")
    app.run(host="0.0.0.0", port=5000, debug=False)
