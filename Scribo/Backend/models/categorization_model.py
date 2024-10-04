from transformers import pipeline

# AI Model BERT for categorizing text into topics
classifier = pipeline('zero-shot-classification', model='facebook/bart-large-mnli')

# Define your categories and subcategories here
categories_with_subcategories = {
    "Anthropology": ["Cultural Anthropology", "Physical Anthropology"],
    "Archaeology": ["Prehistoric Archaeology", "Historical Archaeology"],
    "History": ["Ancient History", "Modern History"],
    "Linguistics": ["Phonetics", "Syntax"],
    "Philosophy": ["Metaphysics", "Ethics"],
    # Add more categories and subcategories as needed...
    "Computer sciences": ["Artificial Intelligence", "Cybersecurity", "Data Science", "Circuits and Systems"]
}

# Function to categorize text and assign subcategories
def categorize_text(text, candidate_labels=None, threshold=0.3):
    if candidate_labels is None:
        # Categories to classify text into topics 
        candidate_labels = list(categories_with_subcategories.keys())
    
    result = classifier(text, candidate_labels, multi_label=True)  # Enable multi-label classification
    categorized_labels = []

    for i, label in enumerate(result['labels']):
        if result['scores'][i] > threshold:
            category = label
            # Check if subcategories exist for this category
            subcategories = categories_with_subcategories.get(category, [])
            
            # Store the category with possible subcategories
            categorized_labels.append({
                "category": category,
                "confidence": result['scores'][i],
                "subcategories": subcategories
            })
    
    return categorized_labels

