import pytesseract
from PIL import Image

# Path to the installed Tesseract executable (if necessary)
# pytesseract.pytesseract.tesseract_cmd = r'/usr/local/bin/tesseract'

def extract_text_from_image(image_path):
    try:
        # Open the image file
        img = Image.open(image_path)
        
        # Convert image to grayscale (optional but often improves OCR accuracy)
        img = img.convert('L')

        # Extract text using Tesseract
        text = pytesseract.image_to_string(img)
        return text
    
    except Exception as e:
        print(f"Error extracting text from image: {e}")
        return None