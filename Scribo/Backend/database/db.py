from pymongo import MongoClient
from datetime import datetime, timezone

# Initialize the MongoDB connection
client = MongoClient('mongodb://localhost:27017/')
db = client['notebook']
notes_collection = db['notes']

# Function to save a note in the database
def save_note(section, subsection, text, text_uuid, summary, image_path, category_source='auto'):
    try:
        note = {
            "id": text_uuid, # Unique ID for the note represented by the text
            "image": {  # Image block
                "type": "image",
                "image_path": image_path
            },
            "topics": {
                "categories": section,
                "subcategories": subsection
            },
            "properties": {  # Meta properties
                "created_at": datetime.now(timezone.utc),
                "updated_at": None,  
                "category_source": category_source  # 'auto' or 'user'
            },
            "content_blocks": [ 
                {
                    "type": "text",
                    "content": text,
                    "summary": summary 
                }
            ],
        }
        notes_collection.insert_one(note)
        return "Note saved successfully"
    
    except Exception as e:
        print(f"Error saving note to the database: {e}")
        return None