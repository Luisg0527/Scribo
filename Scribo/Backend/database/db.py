from pymongo import MongoClient
from datetime import datetime, timezone

# Initialize the MongoDB connection
client = MongoClient('mongodb://localhost:27017/')
db = client['notebook']
notes_collection = db['notes']

# Function to save a note in the database
def save_note(section, subsection, text, category_source='auto'):
    try:
        note = {
            "section": section,
            "subsection": subsection,
            "text": text,
            "timestamp": datetime.now(timezone.utc),
            "category_source": category_source  # 'auto' or 'user'
        }
        notes_collection.insert_one(note)
        return "Note saved successfully"
    except Exception as e:
        print(f"Error saving note to the database: {e}")
        return None
