from transformers import pipeline

# AI Model BERT for categorizing text into topics
classifier = pipeline('zero-shot-classification', model='facebook/bart-large-mnli')
summarizer = pipeline('summarization', model='facebook/bart-large-cnn')

categories_with_subcategories = {
    "Anthropology": ["Cultural Anthropology", "Physical Anthropology"],
    "Archaeology": ["Prehistoric Archaeology", "Historical Archaeology"],
    "History": ["Ancient History", "Modern History"],
    "Linguistics": ["Phonetics", "Syntax"],
    "Philosophy": ["Metaphysics", "Ethics"],
    "Computer sciences": ["Artificial Intelligence", "Cybersecurity", "Data Science", "Circuits"]
}
    # Filter categories based on threshold score
def categorize_text(text, candidate_labels=None, threshold=0.3):
    if candidate_labels is None:
        candidate_labels = list(categories_with_subcategories.keys())

    # Generate a summary of the text
    summary = summarizer(
        text,
        max_length=40,
        min_length=7,
        do_sample=False
    )[0]['summary_text']

    # Perform classification for the main categories
    result = classifier(text, candidate_labels, multi_label=True)
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

    return categorized_labels, summary