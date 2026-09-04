🚗 SmartPark — AI-Powered Smart Parking Management System

«An intelligent, AI-enabled parking management platform that combines computer vision, automated vehicle identification, real-time parking management, and modern web/mobile applications to simplify parking operations and improve the parking experience.»

""Status" (https://img.shields.io/badge/Project-Final%20Year%20Project-blue)" (https://github.com/Touseef355/SmartPark-FYP)
""AI" (https://img.shields.io/badge/AI-Computer%20Vision-green)" (https://github.com/Touseef355/SmartPark-FYP)
""Backend" (https://img.shields.io/badge/Backend-Django-darkgreen)" (https://github.com/Touseef355/SmartPark-FYP)
""Frontend" (https://img.shields.io/badge/Frontend-React%20%2B%20Vite-61DAFB)" (https://github.com/Touseef355/SmartPark-FYP)
""Mobile" (https://img.shields.io/badge/Mobile-Flutter-02569B)" (https://github.com/Touseef355/SmartPark-FYP)
""License" (https://img.shields.io/badge/License-Academic-lightgrey)" (https://github.com/Touseef355/SmartPark-FYP)

---

📌 Overview

SmartPark is an AI-powered Smart Parking Management System developed as a Final Year Project (FYP).

The system is designed to digitize and automate major parking operations by integrating Computer Vision, Artificial Intelligence, web applications, mobile applications, and a centralized backend system.

SmartPark aims to reduce manual parking operations, improve vehicle entry and exit management, provide better visibility into parking activity, and support intelligent parking management.

The platform is structured around multiple components, including:

- 🤖 AI-based vehicle/number-plate processing
- 🚘 Automated entry and exit camera processing
- 🖥️ Parking management dashboards
- 🌐 Web-based interfaces
- 📱 Mobile application components
- 🔐 User and role management
- 📅 Parking bookings
- 💳 Payment management
- 🔔 Notifications
- 📊 Parking management and monitoring

---

🎯 Project Objectives

SmartPark was developed to address common problems in traditional parking systems, including:

- Manual vehicle registration and verification
- Inefficient parking management
- Lack of centralized parking information
- Time-consuming entry and exit processes
- Difficulty monitoring parking operations
- Limited visibility into parking activity and revenue
- Lack of intelligent automation

Our objectives are to:

1. Automate parking operations using AI and computer vision.
2. Improve vehicle entry and exit management.
3. Provide centralized parking management.
4. Support real-time operational monitoring.
5. Simplify booking and payment workflows.
6. Provide role-based dashboards for parking stakeholders.
7. Build a scalable architecture that can be extended with additional AI capabilities.

---

✨ Key Features

🤖 AI & Computer Vision

SmartPark includes a dedicated AI module for computer-vision-based vehicle and number-plate processing.

AI module includes:

- Vehicle/number-plate detection
- YOLOv8-based detection pipeline
- Image preprocessing
- Entry-camera processing
- Exit-camera processing
- Number-plate pattern validation
- Model training utilities
- Detection testing

The repository contains dedicated AI components under:

ai_module/
├── detector.py
├── entry_camera.py
├── exit_camera.py
├── image_preprocessing.py
├── plate_pattern.json
├── test_detector.py
├── train.py
└── yolov8n.pt

---

🚘 Automated Entry & Exit

The system provides separate processing pipelines for parking entry and exit cameras.

The intended workflow is:

Vehicle Arrives
      │
      ▼
Entry Camera
      │
      ▼
Image Processing
      │
      ▼
Number Plate Detection
      │
      ▼
Vehicle Identification
      │
      ▼
Parking Record

The exit workflow follows a similar computer-vision-based process to identify vehicles and update parking records.

---

👥 Role-Based Management

SmartPark is designed around different system roles and management responsibilities.

The platform can support role-specific functionality such as:

- 👤 Customers / Drivers
- 💼 Cashiers / Parking Staff
- 🅿️ Parking Owners
- 🛠️ Administrators

Each role can interact with the functionality relevant to its responsibilities.

---

📊 Parking Management Dashboard

The project includes a dedicated React-based parking dashboard.

The dashboard provides a foundation for managing and monitoring parking operations through a modern web interface.

Current dashboard architecture is based on:

- React
- Vite
- JavaScript
- Recharts
- Component-based UI architecture

---

📅 Booking Management

The backend contains a dedicated booking module for handling parking-related reservations and booking operations.

This allows the system to be extended toward workflows such as:

User
 │
 ▼
Select Parking
 │
 ▼
Check Availability
 │
 ▼
Create Booking
 │
 ▼
Payment
 │
 ▼
Parking Access

---

💳 Payment Management

SmartPark contains a dedicated backend payment module designed to support parking payment workflows.

This architecture allows payment-related functionality to remain separated from the core parking and booking modules.

---

🔔 Notifications

A dedicated notification module is included in the backend architecture for communicating important system events to users and parking staff.

---

🏗️ System Architecture

At a high level, SmartPark follows a modular architecture:

                       ┌─────────────────────┐
                       │      Users          │
                       │ Drivers / Staff     │
                       └──────────┬──────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    │                           │
                    ▼                           ▼
            ┌───────────────┐           ┌───────────────┐
            │ Web Interface │           │ Mobile App    │
            │ React / Vite  │           │ Flutter       │
            └───────┬───────┘           └───────┬───────┘
                    │                           │
                    └─────────────┬─────────────┘
                                  │
                                  ▼
                         ┌─────────────────┐
                         │  Django Backend │
                         │     REST API    │
                         └────────┬────────┘
                                  │
             ┌────────────────────┼────────────────────┐
             │                    │                    │
             ▼                    ▼                    ▼
       ┌───────────┐       ┌────────────┐       ┌────────────┐
       │ Accounts  │       │ Bookings   │       │ Payments   │
       └───────────┘       └────────────┘       └────────────┘
             │                    │                    │
             └────────────────────┼────────────────────┘
                                  │
                                  ▼
                         ┌─────────────────┐
                         │ Parking Module  │
                         └────────┬────────┘
                                  │
                                  ▼
                         ┌─────────────────┐
                         │   AI Module     │
                         │ Computer Vision │
                         └────────┬────────┘
                                  │
                                  ▼
                         ┌─────────────────┐
                         │ Camera / Image  │
                         │    Processing   │
                         └─────────────────┘

---

🧰 Technology Stack

Artificial Intelligence & Computer Vision

- Python
- YOLOv8
- OpenCV
- Image preprocessing
- Computer Vision
- Object detection
- Number-plate processing

Backend

- Python
- Django
- REST API architecture
- PostgreSQL/database integration
- Modular Django applications

Backend modules include:

backend/
├── accounts/
├── ai_module/
├── bookings/
├── notifications/
├── parking/
├── payments/
├── sps_backend/
├── media/
├── manage.py
└── requirements.txt

Web Frontend

- React
- Vite
- JavaScript
- Recharts
- Component-based architecture

Mobile

- Flutter
- Dart
- REST API integration

Other Technologies

- Git & GitHub
- REST APIs
- PostgreSQL
- Nginx
- JSON

---

📁 Repository Structure

SmartPark-FYP/
│
├── ai_module/              # AI & Computer Vision components
│
├── backend/                # Django backend and APIs
│   ├── accounts/
│   ├── ai_module/
│   ├── bookings/
│   ├── notifications/
│   ├── parking/
│   ├── payments/
│   └── sps_backend/
│
├── docs/                   # Project documentation
│
├── landing-page/           # Public landing page
│
├── mobile_app/             # Mobile application resources
│
├── parking-dashboard/      # React/Vite parking dashboard
│
├── parkroo_app/            # Flutter application
│
├── requirements.txt        # Python dependencies
│
└── README.md

---

🚀 Getting Started

1. Clone the Repository

git clone https://github.com/Touseef355/SmartPark-FYP.git
cd SmartPark-FYP

---

🐍 Backend Setup

Navigate to the backend:

cd backend

Create a virtual environment:

Windows

python -m venv venv
venv\Scripts\activate

Linux / macOS

python3 -m venv venv
source venv/bin/activate

Install dependencies:

pip install -r requirements.txt

Run migrations:

python manage.py migrate

Start the Django development server:

python manage.py runserver

The backend will normally be available at:

http://127.0.0.1:8000/

«Configuration such as database credentials, secret keys, API keys, and other environment-specific values should be provided through environment variables rather than committed to Git.»

---

🤖 AI Module Setup

Navigate to the AI module:

cd ai_module

Install the required Python dependencies from the project's requirements configuration.

The AI module contains training, testing, image preprocessing, detection, and entry/exit camera processing components.

Example:

python train.py

«Model training requirements depend on the dataset, hardware, and configuration used for your specific experiment.»

---

💻 Parking Dashboard Setup

Navigate to the dashboard:

cd parking-dashboard

Install Node.js dependencies:

npm install

Start the development server:

npm run dev

The dashboard uses React + Vite and includes charting functionality through Recharts.

---

📱 Mobile Application

The repository contains Flutter application components under:

parkroo_app/

A standard Flutter setup can be used:

cd parkroo_app
flutter pub get
flutter run

Make sure Flutter and the required Android/iOS development environment are installed before running the application.

---

🔐 Environment Variables

For security, sensitive configuration should never be committed to GitHub.

Examples include:

SECRET_KEY=your_secret_key
DEBUG=True
DATABASE_URL=your_database_url
API_KEY=your_api_key

Create a local ".env" file where required and add it to ".gitignore".

Never publish:

- Passwords
- API keys
- Database credentials
- Authentication tokens
- Private certificates
- Production secrets

---

🧪 Testing

The AI module includes dedicated testing utilities such as:

test_detector.py

Run the relevant tests according to the module configuration.

For backend testing:

python manage.py test

---

🔄 Application Workflow

A simplified SmartPark workflow is:

                 USER
                   │
                   ▼
          Web / Mobile Application
                   │
                   ▼
             Django API
                   │
        ┌──────────┼──────────┐
        │          │          │
        ▼          ▼          ▼
     Parking    Booking    Payment
        │          │          │
        └──────────┼──────────┘
                   │
                   ▼
             AI Processing
                   │
                   ▼
          Camera / Detection
                   │
                   ▼
       Vehicle & Plate Information
                   │
                   ▼
          Parking Record Update

---

📈 Future Improvements

The SmartPark architecture can be further extended with:

- Real-time parking-space detection
- Advanced license plate recognition/OCR
- Real-time parking availability
- Intelligent parking recommendations
- Advanced analytics and reporting
- Peak-hour prediction
- Cloud deployment
- WebSocket-based real-time updates
- Improved mobile integration
- Automated gate integration
- Production-grade authentication and authorization
- AI model optimization for edge devices

---

🎓 Academic Project

SmartPark was developed as a Final Year Project (FYP) with the goal of applying modern software engineering and artificial intelligence techniques to a real-world transportation and parking-management problem.

The project combines concepts from:

- Artificial Intelligence
- Machine Learning
- Computer Vision
- Software Engineering
- Web Development
- Mobile Application Development
- Database Systems
- API Development

---

👨‍💻 Author

Touseef Ahmed

GitHub:
"@Touseef355" (https://github.com/Touseef355)

Project Repository:
https://github.com/Touseef355/SmartPark-FYP

---

🤝 Contributing

This repository is primarily an academic project. However, suggestions, improvements, bug reports, and technical contributions are welcome.

If you would like to contribute:

1. Fork the repository.
2. Create a feature branch.
3. Make your changes.
4. Test your changes.
5. Commit your changes.
6. Open a Pull Request.

Example:

git checkout -b feature/new-feature
git add .
git commit -m "Add new feature"
git push origin feature/new-feature

---

📄 License

This project is intended primarily for academic and educational purposes.

If you intend to distribute, modify, or use the project commercially, please contact the repository owner regarding licensing.

---

⭐ Support

If you find this project useful or interesting, consider giving the repository a ⭐ on GitHub.

SmartPark — Making Parking Smarter with AI. 🚗🤖
