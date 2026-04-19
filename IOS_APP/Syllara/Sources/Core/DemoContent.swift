import Foundation

enum DemoContent {
    static let courses: [Course] = [
        Course(
            id: "cs510",
            course_code: "CS510",
            name: "Design and Analysis of Algorithms",
            workflow_state: "available",
            color: "CC0033",
            instructor: "Prof. Singh",
            credits: 3,
            progress: 72
        ),
        Course(
            id: "cs520",
            course_code: "CS520",
            name: "Introduction to Artificial Intelligence",
            workflow_state: "available",
            color: "FF6B35",
            instructor: "Prof. Chen",
            credits: 3,
            progress: 64
        ),
        Course(
            id: "cs527",
            course_code: "CS527",
            name: "Database Management Systems",
            workflow_state: "available",
            color: "2EC4B6",
            instructor: "Prof. Patel",
            credits: 3,
            progress: 81
        ),
        Course(
            id: "cs533",
            course_code: "CS533",
            name: "Computer Security",
            workflow_state: "available",
            color: "F4D35E",
            instructor: "Prof. Kim",
            credits: 3,
            progress: 58
        )
    ]

    static let assignments: [Assignment] = [
        Assignment(
            id: "a1",
            course_id: "cs510",
            name: "Approximation Algorithms Problem Set",
            assignment_category: "Homework",
            due_at: "2026-04-20T23:59:00Z",
            points_possible: 100,
            description: "Focus on set cover and primal-dual techniques.",
            status: "pending",
            priority: "critical",
            has_submitted_submissions: false
        ),
        Assignment(
            id: "a2",
            course_id: "cs520",
            name: "A* Search Implementation",
            assignment_category: "Project",
            due_at: "2026-04-22T20:00:00Z",
            points_possible: 50,
            description: "Implement heuristic search over a weighted grid.",
            status: "pending",
            priority: "high",
            has_submitted_submissions: false
        ),
        Assignment(
            id: "a3",
            course_id: "cs527",
            name: "Normalization Worksheet",
            assignment_category: "Lab",
            due_at: "2026-04-25T17:00:00Z",
            points_possible: 25,
            description: "Derive 3NF schemas from the supplied cases.",
            status: "pending",
            priority: "medium",
            has_submitted_submissions: false
        )
    ]

    static let announcements: [Announcement] = [
        Announcement(
            id: "ann1",
            course_id: "cs510",
            title: "Midterm review sheet posted",
            message: "Review problems cover greedy proofs, DP, and LP duality.",
            posted_at: "2026-04-18T15:00:00Z",
            author: "Prof. Singh",
            priority: "high"
        ),
        Announcement(
            id: "ann2",
            course_id: "cs520",
            title: "Project rubric updated",
            message: "The heuristic admissibility section now counts for 15 points.",
            posted_at: "2026-04-17T18:30:00Z",
            author: "TA Team",
            priority: "medium"
        ),
        Announcement(
            id: "ann3",
            course_id: "cs533",
            title: "Guest lecture on threat modeling",
            message: "Thursday class will meet in the seminar room.",
            posted_at: "2026-04-16T13:00:00Z",
            author: "Prof. Kim",
            priority: "low"
        )
    ]

    static let conceptNodes: [ConceptNode] = [
        ConceptNode(id: "dp", label: "Dynamic Programming", course_id: "cs510", description: "State design, recurrence reasoning, and optimal substructure."),
        ConceptNode(id: "heuristics", label: "Heuristic Search", course_id: "cs520", description: "Admissibility, consistency, and informed search tradeoffs."),
        ConceptNode(id: "normalization", label: "Normalization", course_id: "cs527", description: "Functional dependencies and schema decomposition."),
        ConceptNode(id: "threat-modeling", label: "Threat Modeling", course_id: "cs533", description: "Assets, abuse paths, and mitigation planning.")
    ]

    static let conceptEdges: [ConceptEdge] = [
        ConceptEdge(source: "dp", target: "heuristics", relationship: "supports"),
        ConceptEdge(source: "normalization", target: "threat-modeling", relationship: "interacts with"),
        ConceptEdge(source: "heuristics", target: "threat-modeling", relationship: "informs")
    ]
}
