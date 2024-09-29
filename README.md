# Scribo
A notes application integrated with AI.


## Installation Instructions

### 1. Python Dependencies

First, ensure you have **Python 3.x** installed on your system. To install the required Python packages, follow these steps:

1. Clone the repository and navigate to the project directory:
   
   ```bash
   git clone <repository-url>
   cd <project-directory>
   ```

2. Install Python dependencies:

   ```bash
   pip install -r requirements.txt
   ```

This will install the following Python packages:
- **Flask**: A lightweight web framework.
- **pytesseract**: A Python wrapper for the Tesseract-OCR engine.
- **Pillow**: A Python Imaging Library that adds image processing capabilities.
- **pymongo**: A MongoDB driver if your app uses MongoDB for data storage.

### 2. System-Level Tesseract-OCR Installation

To extract text from images, **Tesseract-OCR** must be installed on your system.

#### For Ubuntu/Debian:

```bash
sudo apt-get update
sudo apt-get install tesseract-ocr
```

#### For macOS (using Homebrew):

```bash
brew install tesseract
```

#### For Windows:

1. Download the **Tesseract** installer from the official page [here](https://github.com/UB-Mannheim/tesseract/wiki).
2. Run the installer and follow the on-screen instructions.
3. Add Tesseract to your system’s PATH:
   - Open **Control Panel** > **System and Security** > **System**.
   - Click **Advanced system settings**.
   - Under **System Variables**, select **Path** and click **Edit**.
   - Add the location of Tesseract (e.g., `C:\Program Files\Tesseract-OCR`).

#### Verify the Installation:

After installation, verify that Tesseract-OCR is properly installed by running:

```bash
tesseract --version
```

This should display the installed version of Tesseract.

### 3. Running the Application

Once all dependencies and Tesseract-OCR are installed, you can run the Flask app:

```bash
python app.py
```

Your Flask application will now be running, and you can use the API to upload images and extract text using Tesseract-OCR.

---

### Additional Configuration (Windows Only):

If you're running this application on **Windows**, you may need to explicitly set the path to the `tesseract.exe` file in your Python code. Add the following to your Flask app before using `pytesseract`:

```python
import pytesseract

# Set the path to the Tesseract executable (Windows only)
pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'
```
