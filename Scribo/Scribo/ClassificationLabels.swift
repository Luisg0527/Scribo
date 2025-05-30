import Foundation

struct ClassificationLabels {
    // MARK: - Main Topics with Descriptions
    static let mainTopics: [(String, String)] = [
        ("Mathematics", "Numbers, calculations, equations, and mathematical concepts"),
        ("Science", "Natural phenomena, experiments, and scientific research"),
        ("History", "Past events, historical periods, and historical analysis"),
        ("Literature", "Written works, books, and literary analysis"),
        ("Technology", "Computers, software, hardware, and technical systems"),
        ("Business", "Commerce, management, and economic activities"),
        ("Arts", "Creative expression, visual arts, and artistic works"),
        ("Language", "Communication, linguistics, and language study"),
        ("Philosophy", "Abstract concepts, reasoning, and philosophical thought"),
        ("Health", "Medical topics, wellness, and healthcare"),
        ("Religion", "Spiritual beliefs, religious practices, and theology")
    ]
    
    // MARK: - Science Subtopics with Descriptions
    static let scienceSubtopics: [(String, String)] = [
        ("Physics", "Physical laws, forces, and matter"),
        ("Chemistry", "Chemical reactions, elements, and compounds"),
        ("Biology", "Living organisms and life processes"),
        ("Astronomy", "Celestial objects and space phenomena"),
        ("Geology", "Earth's structure and processes"),
        ("Computer Science", "Computing systems and algorithms")
    ]
    
    // MARK: - Mathematics Subtopics with Descriptions
    static let mathematicsSubtopics: [(String, String)] = [
        ("Algebra", "Mathematical symbols and equations"),
        ("Calculus", "Rates of change and accumulation"),
        ("Geometry", "Shapes, sizes, and spatial relationships"),
        ("Statistics", "Data analysis and probability"),
        ("Number Theory", "Properties and relationships of numbers")
    ]
    
    // MARK: - History Subtopics with Descriptions
    static let historySubtopics: [(String, String)] = [
        ("Ancient History", "Early civilizations and classical periods"),
        ("Modern History", "Recent historical events and developments"),
        ("World History", "Global historical perspectives"),
        ("Cultural History", "Social and cultural developments"),
        ("Political History", "Political systems and events")
    ]
    
    // MARK: - Literature Subtopics with Descriptions
    static let literatureSubtopics: [(String, String)] = [
        ("Poetry", "Verse and poetic forms"),
        ("Fiction", "Imaginative narrative works"),
        ("Non-Fiction", "Factual and informative writing"),
        ("Drama", "Theatrical works and scripts"),
        ("Literary Analysis", "Critical examination of texts")
    ]
    
    // MARK: - Technology Subtopics with Descriptions
    static let technologySubtopics: [(String, String)] = [
        ("Programming", "Software development and coding"),
        ("Artificial Intelligence", "Machine learning and AI systems"),
        ("Web Development", "Internet and web technologies"),
        ("Mobile Development", "Mobile applications and platforms"),
        ("Data Science", "Data analysis and processing")
    ]
    
    // MARK: - Business Subtopics with Descriptions
    static let businessSubtopics: [(String, String)] = [
        ("Economics", "Economic systems and principles"),
        ("Marketing", "Promotion and market strategies"),
        ("Finance", "Financial management and markets"),
        ("Management", "Business operations and leadership"),
        ("Entrepreneurship", "Business creation and innovation")
    ]
    
    // MARK: - Arts Subtopics with Descriptions
    static let artsSubtopics: [(String, String)] = [
        ("Visual Arts", "Painting, drawing, and visual media"),
        ("Music", "Musical composition and performance"),
        ("Dance", "Movement and choreography"),
        ("Film", "Cinema and motion pictures"),
        ("Architecture", "Building design and construction")
    ]
    
    // MARK: - Language Subtopics with Descriptions
    static let languageSubtopics: [(String, String)] = [
        ("Grammar", "Language structure and rules"),
        ("Vocabulary", "Word usage and meaning"),
        ("Writing", "Written communication"),
        ("Speaking", "Oral communication and speech"),
        ("Translation", "Language conversion and interpretation")
    ]
    
    // MARK: - Philosophy Subtopics with Descriptions
    static let philosophySubtopics: [(String, String)] = [
        ("Ethics", "Moral principles and values"),
        ("Logic", "Reasoning and argumentation"),
        ("Metaphysics", "Nature of reality and existence"),
        ("Epistemology", "Theory of knowledge"),
        ("Political Philosophy", "Political theory and governance")
    ]
    
    // MARK: - Health Subtopics with Descriptions
    static let healthSubtopics: [(String, String)] = [
        ("Medicine", "Medical treatment and healthcare"),
        ("Nutrition", "Diet and food science"),
        ("Psychology", "Mental processes and behavior"),
        ("Exercise", "Physical activity and fitness"),
        ("Mental Health", "Psychological well-being")
    ]
    
    // MARK: - Religion Subtopics with Descriptions
    static let religionSubtopics: [(String, String)] = [
        ("Religious Studies", "Study of religious beliefs and practices"),
        ("Theology", "Religious doctrine and theory"),
        ("Religious History", "Historical development of religions"),
        ("Religious Philosophy", "Philosophical aspects of religion"),
        ("Comparative Religion", "Comparison of different religions")
    ]
    
    // MARK: - Helper Methods
    static func getTopicDescription(_ topic: String) -> String {
        return mainTopics.first { $0.0 == topic }?.1 ?? ""
    }
    
    static func getSubtopicDescription(_ subtopic: String) -> String {
        let allSubtopics = scienceSubtopics + mathematicsSubtopics + historySubtopics +
            literatureSubtopics + technologySubtopics + businessSubtopics +
            artsSubtopics + languageSubtopics + philosophySubtopics +
            healthSubtopics + religionSubtopics
        
        return allSubtopics.first { $0.0 == subtopic }?.1 ?? ""
    }
    
    // MARK: - All Labels
    static var allLabels: [String] {
        return mainTopics.map { $0.0 } +
            scienceSubtopics.map { $0.0 } +
            mathematicsSubtopics.map { $0.0 } +
            historySubtopics.map { $0.0 } +
            literatureSubtopics.map { $0.0 } +
            technologySubtopics.map { $0.0 } +
            businessSubtopics.map { $0.0 } +
            artsSubtopics.map { $0.0 } +
            languageSubtopics.map { $0.0 } +
            philosophySubtopics.map { $0.0 } +
            healthSubtopics.map { $0.0 } +
            religionSubtopics.map { $0.0 }
    }
    
    // MARK: - Label Pairs for Classification
    static var labelPairs: [(String, String)] {
        return mainTopics + scienceSubtopics + mathematicsSubtopics +
            historySubtopics + literatureSubtopics + technologySubtopics +
            businessSubtopics + artsSubtopics + languageSubtopics +
            philosophySubtopics + healthSubtopics + religionSubtopics
    }
} 