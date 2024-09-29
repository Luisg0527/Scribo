import pytesseract
from PIL import Image

def extract_text_from_image(image_path):
    try:
        img = Image.open(image_path)
        
        # Convert image to grayscale (optional but often improves OCR accuracy)
        img = img.convert('L')

        text = pytesseract.image_to_string(img)
        return text
    
    except Exception as e:
        print(f"Error extracting text from image: {e}")
        return None