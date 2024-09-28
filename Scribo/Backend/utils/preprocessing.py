from nltk.corpus import stopwords
import re

# Function to preprocess the extracted text
def clean_text(text):
    # Remove any special characters and digits
    text = re.sub(r'\W+', ' ', text)
    text = re.sub(r'\d+', '', text)

    # Convert to lowercase
    text = text.lower()

    # Optionally, remove stopwords
    stop_words = set(stopwords.words('english'))
    text = ' '.join([word for word in text.split() if word not in stop_words])

    return text