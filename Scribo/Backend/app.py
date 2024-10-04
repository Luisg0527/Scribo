from flask import Flask, request, jsonify
from ocr.OCR import extract_text_from_image
from models.categorization_model import categorize_text
from database.db import save_note
from database.db import notes_collection  
# Recommendation: Use Conda for managing the environment

app = Flask(__name__)

# Endpoint for OCR + Categorization
@app.route('/upload-image', methods=['POST'])
def upload_image():
    # Check if the file is in the request
    if 'file' not in request.files:
        return jsonify({"error": "No file part in the request"}), 400
    
    file = request.files['file']
      
    # Check if a file was actually selected
    if file.filename == '':
        return jsonify({"error": "No file selected"}), 400

    # Perform OCR to extract text from the image
    text = extract_text_from_image(file)
    
    # Check if the OCR extraction was successful
    if not text:
        return jsonify({"error": "Failed to extract text from the image"}), 500

    # Automatically categorize the extracted text
    categorized_output = categorize_text(text)

    # Ensure categorized_output contains labels (assuming a list of categories is returned)
    if not categorized_output or not categorized_output[0]['category']:
        return jsonify({"error": "Failed to categorize text"}), 500

    # Get the top category and its subcategories
    top_category = categorized_output[0]['category']
    subcategories = categorized_output[0].get('subcategory', [])

    # Get the user-provided category, if available
    user_provided_category = request.form.get('category')

    # Use the user's category if provided, otherwise use the automatically categorized section
    selected_category = user_provided_category if user_provided_category else top_category

    # Determine if the category was provided by the user or auto-generated
    category_source = 'user' if user_provided_category else 'auto'

    # Save the note with the selected category and extracted text
    save_note(selected_category, selected_category, text, category_source)

    # Return the response with both the selected category, extracted text, and subcategories
    return jsonify({
        "message": "Text categorized and saved",
        "category": selected_category,
        "subcategory": subcategories,  # Add subcategories to the response
        "extracted_text": text
    }), 200

# Endpoint for adding note manually
@app.route('/add-note', methods=['POST'])
def add_note():
    try:
        # Get the JSON data from the request
        data = request.get_json()

        # Check if all required fields are present
        section = data.get('section')
        subsection = data.get('subsection')
        text = data.get('text')

        if not section or not subsection or not text:
            return jsonify({"error": "Missing data"}), 400

        # Call the save_note function to save the note in the database
        result = save_note(section, subsection, text)

        # If result is None, the note saving failed
        if result is None:
            return jsonify({"error": "Failed to save note"}), 500  # Return 500 if saving fails, Probably due to MongoDB not running

        # Return a success message if the note was saved successfully
        return jsonify({"message": result}), 201

    except Exception as e:
        print(f"Error: {e}")  
        return jsonify({"error": "An internal server error occurred"}), 500  # Return 500 for general errors

# Endpoint for retrieving all notes
@app.route('/get-notes', methods=['GET'])
def get_notes():
    try:
        # Fetch all notes from the MongoDB collection
        notes = list(notes_collection.find({}, {"_id": 0}))  # Exclude the MongoDB ObjectId (_id)
        return jsonify(notes), 200
    except Exception as e:
        print(f"Error fetching notes: {e}")
        return jsonify({"error": "Failed to retrieve notes"}), 500

# Run the app
if __name__ == '__main__':
    app.run(debug=True)
