# UI Specification for LEC Flutter Agent
# This file outlines the UI structure and requirements to cover 100% of the backend functionality.

UI_SPEC = {
    "app_name": "LEC Agent",
    "theme": {
        "primary_color": "Blue",
        "aesthetic": "Simple, Clean, Student-focused",
        "font": "Standard Sans-serif"
    },
    "screens": [
        {
            "name": "Auth",
            "features": ["Login", "Registration", "Password Reset", "Token Refresh (Background)"]
        },
        {
            "name": "Home / Dashboard",
            "features": [
                "Continue Watching (Last 5 lessons)",
                "Latest Courses",
                "Stats Overview (Analytical summary)",
                "Global Search"
            ]
        },
        {
            "name": "Course Browser",
            "features": [
                "List all courses (Public/Default)",
                "Filter by Tag",
                "Course Details (Description, Instructor info)",
                "Lesson List (Locked/Unlocked status indicators)"
            ]
        },
        {
            "name": "Lesson Player",
            "features": [
                "HLS Video Player (m3u8 via Main Server Proxy)",
                "Material List (PDF Viewer, Link opener)",
                "Comments Section (Nested comments, Write comment)",
                "Lock Logic (Prevents access based on backend rules)",
                "Watch Progress Tracking (Auto-sync to stats API)"
            ]
        },
        {
            "name": "Quiz / Examination",
            "features": [
                "Quiz Intro (Passing score, Time limit)",
                "Multiple Choice Question Interface",
                "Result Page (Score, Pass/Fail status)"
            ]
        },
        {
            "name": "User Profile",
            "features": [
                "User Details (Update Name/Email/Avatar)",
                "My Courses (Enrolled list)",
                "Access Code Redemption",
                "Logout"
            ]
        },
        {
            "name": "Support / Interactions",
            "features": [
                "Direct Messaging (DMs with instructors)",
                "Report Content (Report Video/Lesson/Comment)",
                "Inbox for notifications/messages"
            ]
        },
        {
            "name": "Admin/Instructor Dashboard (Conditional)",
            "features": [
                "Manage Courses/Lessons (CRUD UI)",
                "User Management (Ban/Unban/Grant Access)",
                "Analytical Stats (Instructor-specific stats)",
                "Access Code Generation"
            ]
        }
    ],
    "technical_requirements": [
        "Use package:agent/agent.dart for all backend interactions",
        "Handle ApiException gracefully with user-friendly snackbars",
        "Implement 'Continue Watching' using local persistence + Stats API",
        "Secure HLS streaming with proxy URL handling",
        "Responsive design for both Phone and Tablet"
    ]
}

if __name__ == "__main__":
    import json
    print("--- LEC UI Specification ---")
    print(json.dumps(UI_SPEC, indent=4))
