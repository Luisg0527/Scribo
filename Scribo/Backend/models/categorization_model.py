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
    "Computer sciences": ["Artificial Intelligence", "Cybersecurity", "Data Science", "Circuits"]
}

def categorize_text(text, candidate_labels=None, candidate_sublabels=None, threshold=0.3):
    if candidate_labels is None:
        # Categories to classify text into topics 
        candidate_labels = list(categories_with_subcategories.keys())

    # Perform classification for the main category
    result = classifier(text, candidate_labels, multi_label=True)  # Enable multi-label classification
    categorized_labels = []

    # Filter categories based on threshold score
    for i, label in enumerate(result['labels']):
        if result['scores'][i] > threshold:
            category = label
            categorized_labels.append({
                "category": category,
                "confidence": result['scores'][i],
            })

            # Get subcategories for the classified category
            candidate_sublabels = categories_with_subcategories.get(category, [])
            if candidate_sublabels:
                # Perform classification for subcategories
                subresult = classifier(text, candidate_sublabels, multi_label=True)

                # Filter subcategories based on threshold score
                for j, sublabel in enumerate(subresult['labels']):
                    if subresult['scores'][j] > threshold:
                        categorized_labels[-1]["subcategory"] = sublabel
                        categorized_labels[-1]["subcategory_confidence"] = subresult['scores'][j]

    return categorized_labels
