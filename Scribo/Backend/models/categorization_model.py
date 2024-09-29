from transformers import pipeline

# AI Model BERT for categorizing text into topics
classifier = pipeline('zero-shot-classification', model='facebook/bart-large-mnli')

def categorize_text(text, candidate_labels=None):
    if candidate_labels is None:
        # Categories to classify text into topics 
        candidate_labels = ["Mathematics", "Physics", "Chemistry", "History", "Biology", "Computer Science"]
    
    result = classifier(text, candidate_labels)
    return result