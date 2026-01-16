# Learning Behavior Analysis App

Mobile app for early identification of learning-impacting behavioral patterns in children.

## Project Overview

This app helps identify behavioral patterns in children that may impact learning through:
- Interactive activities for children
- Pattern analysis using Gemini API
- Insights for parents and teachers

## Tech Stack

- **Frontend**: Flutter
- **Backend**: FastAPI (Python)
- **Database & Auth**: Supabase
- **GenAI**: Gemini API

## Setup Instructions

### Frontend (Flutter)
1. Install Flutter SDK
2. Run `flutter pub get` to install dependencies
3. Configure Supabase credentials in the app
4. Run with `flutter run`

### Backend (FastAPI)
1. Create virtual environment: `python -m venv venv`
2. Activate environment: `source venv/bin/activate` (Unix) or `venv\Scripts\activate` (Windows)
3. Install dependencies: `pip install -r requirements.txt`
4. Configure environment variables for Supabase and Gemini API
5. Run the server: `uvicorn backend.main:app --reload`

## Key Features

- **User Roles**: Children (players), parents, and teachers
- **Activities**: Interactive games to identify behavioral patterns
- **Analysis**: Pattern identification using activity data
- **Insights**: Explanations and recommendations for parents/teachers