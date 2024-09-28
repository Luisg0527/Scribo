from flask import Flask, request, jsonify
from ocr.OCR import extract_text_from_image
from models.categorization_model import categorize_text
from database.db import save_note

app = Flask(__name__)

# Endpoint for OCR + Categorization
@app.route('/upload-image', methods=['POST'])
def upload_image():
    if 'file' not in request.files:
        return jsonify({"error": "No file part"}), 400
    
    file = request.files['file']
    if file.filename == '':
        return jsonify({"error": "No selected file"}), 400

    # Perform OCR to extract text from the image
    text = extract_text_from_image(file)
    
    if not text:
        return jsonify({"error": "Failed to extract text from image"}), 500

    # Automatically categorize the text
    categorized_output = categorize_text(text)
    section = categorized_output['labels'][0]  # Get the top category label

    # Check if the user provides a correct category
    user_provided_category = request.form.get('category')

    # Use the user's category if provided, otherwise use the automatically categorized section
    if user_provided_category:
        section = user_provided_category

    # Save the note with either 'auto' or 'user' depending on how the category was chosen
    category_source = 'user' if user_provided_category else 'auto'
    save_note(section, section, text, category_source)

    # Return the response with both the categorized section and the extracted text
    return jsonify({
        "message": "Text categorized and saved",
        "section": section,
        "extracted_text": text
    }), 200

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
            return jsonify({"error": "Failed to save note"}), 500  # Return 500 if saving fails

        # Return a success message if the note was saved successfully
        return jsonify({"message": result}), 201

    except Exception as e:
        print(f"Error: {e}")  # Log the exception
        return jsonify({"error": "An internal server error occurred"}), 500  # Return 500 for general errors

# Run the app
if __name__ == '__main__':
    app.run(debug=True)
