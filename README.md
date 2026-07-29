# AutoFix - Vehicle Management Application

A comprehensive Flutter-based vehicle management system designed for automotive service centers, repair shops, and vehicle maintenance facilities. AutoFix streamlines the entire workflow from vehicle pickup to service completion with role-based access control and real-time tracking.

## 📱 Overview

AutoFix is a modern, cross-platform mobile application built with Flutter that provides a complete solution for vehicle service management. The app supports multiple user roles and offers features ranging from job card creation to detailed analytics and reporting.

## 🚀 Key Features

### 🔐 Authentication & Security
- **Multi-role Authentication**: Support for Admin, Executive, Inspector, Washer, Telecaller, and Pickup/Dropoff roles
- **Biometric Authentication**: Fingerprint and face recognition support
- **Secure Session Management**: JWT-based authentication with automatic token refresh
- **Auto-logout**: Configurable session timeout for security

### 👥 User Roles & Permissions

#### **Admin**
- Complete system oversight and management
- User management and role assignment
- Vehicle database management
- Analytics and reporting dashboard
- App settings and configuration
- Quick access to all user accounts

#### **Executive**
- Job card creation and management
- Vehicle inspection and assessment
- Customer communication
- Report generation and updates
- Service workflow management

#### **Inspector**
- Vehicle inspection and quality control
- Inspection approval/rejection workflow
- Detailed inspection reports
- Photo documentation

#### **Washer**
- Vehicle cleaning and preparation
- Wash status updates
- Quality control checks

#### **Telecaller**
- Customer communication
- Appointment scheduling
- Follow-up calls and updates
- Customer service management

#### **Pickup/Dropoff (PUDO)**
- Vehicle pickup and delivery
- Location-based navigation
- Customer contact management
- Delivery status tracking

### 🚗 Vehicle Management
- **Vehicle Database**: Comprehensive vehicle information storage
- **Vehicle Search**: Quick lookup by registration number
- **Vehicle Models**: Brand and model management
- **Odometer Tracking**: Automatic odometer reading updates
- **Client Information**: Customer details and contact management

### 📋 Job Card System
- **Digital Job Cards**: Paperless job card creation and management
- **Multi-step Workflow**: From pickup to completion
- **Status Tracking**: Real-time status updates throughout the service process
- **Photo Documentation**: Before/after service photos
- **Voice Notes**: Audio recording for detailed notes
- **OCR Integration**: Automatic text extraction from documents

### 📊 Reporting & Analytics
- **Comprehensive Reports**: Detailed service reports with photos and notes
- **Analytics Dashboard**: Performance metrics and insights
- **Export Options**: PDF and CSV export functionality
- **Real-time Updates**: Live data synchronization
- **Historical Data**: Complete service history tracking

### 🔄 Workflow Management
- **Status Progression**: Not Started → Ongoing → Inspection → Washing → Completed
- **Role-based Actions**: Different actions available based on user role
- **Approval Workflows**: Multi-level approval system
- **Notification System**: Real-time notifications for status changes

### 📱 User Experience
- **Modern UI/UX**: Clean, intuitive interface design
- **Offline Support**: Local data caching and offline functionality
- **Real-time Sync**: Automatic data synchronization when online
- **Responsive Design**: Optimized for various screen sizes
- **Accessibility**: Support for accessibility features

## 🛠 Technical Architecture

### **Frontend (Flutter)**
- **Framework**: Flutter 3.0+
- **State Management**: Provider pattern
- **UI Components**: Material Design 3
- **Navigation**: Flutter Navigator 2.0
- **Local Storage**: SQLite + SharedPreferences
- **Image Handling**: Image picker with compression
- **Audio Recording**: Real-time audio recording and playback

### **Backend (Supabase)**
- **Database**: PostgreSQL with real-time subscriptions
- **Authentication**: Supabase Auth with JWT
- **File Storage**: Supabase Storage for images and documents
- **Real-time**: WebSocket connections for live updates
- **API**: RESTful API with automatic documentation

### **External Services**
- **Google Drive**: Document storage and sharing
- **OCR Service**: Text extraction from images
- **Maps Integration**: Location services and navigation
- **Push Notifications**: Firebase Cloud Messaging
- **PDF Generation**: Dynamic PDF creation

## 📁 Project Structure

```
lib/
├── main.dart                 # Application entry point
├── models/                   # Data models
│   └── admin_setting_model.dart
├── providers/                # State management
│   ├── admin_settings_provider.dart
│   ├── report_provider.dart
│   ├── user_preferences_provider.dart
│   └── user_provider.dart
├── screens/                  # UI screens
│   ├── admin/               # Admin-specific screens
│   │   ├── admin_dashboard_screen.dart
│   │   ├── analytics_screen.dart
│   │   ├── app_settings_screen.dart
│   │   ├── reports_analytics_screen.dart
│   │   ├── user_management_screen.dart
│   │   └── vehicle_management_screen.dart
│   ├── close_screen.dart
│   ├── inspector_screen.dart
│   ├── job_card_screen.dart
│   ├── login_screen.dart
│   ├── main_dashboard.dart
│   ├── profile_screen.dart
│   ├── pudo_dashboard_screen.dart
│   ├── pudo_job_card_screen.dart
│   ├── report_screen.dart
│   ├── telecaller_dashboard_screen.dart
│   ├── update_screen.dart
│   └── washer_screen.dart
├── services/                 # Business logic and API calls
│   ├── auth_helper.dart
│   ├── biometric_auth_service.dart
│   ├── cache_service.dart
│   ├── connectivity_service.dart
│   ├── database_helper.dart
│   ├── google_drive_service.dart
│   ├── inactivity_service.dart
│   ├── notification_service.dart
│   ├── ocr_service.dart
│   └── supabase_service.dart
├── theme/                    # UI theming
│   ├── app_theme.dart
│   └── app_typography.dart
├── utils/                    # Utility functions
│   ├── app_constants.dart
│   ├── app_exceptions.dart
│   └── validators.dart
└── widgets/                  # Reusable UI components
    ├── common_job_card.dart
    ├── empty_state.dart
    ├── error_display.dart
    ├── loading_dialog.dart
    ├── printable_job_card.dart
    ├── quick_access_dialog.dart
    └── skeleton_loading.dart
```

## 🔄 Workflow Overview

### **1. Vehicle Pickup Process**
```
Customer Request → Telecaller Contact → PUDO Pickup → Vehicle Transport → Service Center
```

### **2. Service Workflow**
```
Job Card Creation → Vehicle Inspection → Service Planning → Parts Ordering → Service Execution → Quality Control → Final Inspection → Customer Notification → Vehicle Delivery
```

### **3. Status Progression**
```
Not Started → Ongoing → Inspection → Washing → Completed
```

### **4. Role Interactions**
- **Telecaller**: Initiates customer contact and appointment scheduling
- **PUDO**: Handles vehicle pickup and delivery
- **Executive**: Creates job cards and manages service workflow
- **Inspector**: Performs quality control and inspection
- **Washer**: Handles vehicle cleaning and preparation
- **Admin**: Oversees entire process and manages system

## 🚀 Getting Started

### **Prerequisites**
- Flutter SDK 3.0 or higher
- Dart SDK 3.0 or higher
- Android Studio / VS Code
- Git

### **Installation**

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd autofix_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Supabase**
   - Create a Supabase project
   - Update the Supabase URL and API key in `lib/main.dart`
   - Set up the database schema

4. **Run the application**
   ```bash
   flutter run
   ```

### **Environment Setup**

1. **Supabase Configuration**
   - Create tables for users, vehicles, job_cards, reports
   - Set up Row Level Security (RLS) policies
   - Configure authentication providers

2. **Google Services**
   - Set up Google Drive API
   - Configure Google Sign-In
   - Add Google Maps API key

3. **Firebase Setup**
   - Configure Firebase project
   - Set up Cloud Messaging
   - Add configuration files

## 📱 Screenshots

### **Login & Authentication**
- Secure login with biometric support
- Role-based dashboard routing
- Session management

### **Dashboard Views**
- **Admin Dashboard**: System overview and management
- **Executive Dashboard**: Job card management and workflow
- **PUDO Dashboard**: Pickup and delivery management
- **Inspector Dashboard**: Quality control and inspection
- **Washer Dashboard**: Cleaning and preparation tasks

### **Job Card Management**
- Digital job card creation
- Photo documentation
- Voice notes and comments
- Status tracking and updates

### **Reporting & Analytics**
- Comprehensive service reports
- Performance metrics
- Export functionality
- Historical data analysis

## 🔧 Configuration

### **App Settings**
- **User Preferences**: Biometric auth, haptic feedback, animations
- **Auto-logout**: Configurable session timeout
- **Notifications**: Push notification preferences
- **Theme**: Light theme (dark mode removed as requested)

### **Admin Settings**
- **User Management**: Add, edit, remove users
- **Role Assignment**: Assign and modify user roles
- **Vehicle Management**: Manage vehicle database
- **System Configuration**: App-wide settings

## 🚨 Troubleshooting

### **Common Issues**

1. **Authentication Errors**
   - Check Supabase configuration
   - Verify API keys and URLs
   - Ensure proper role assignments

2. **Database Connection Issues**
   - Verify Supabase connection
   - Check network connectivity
   - Review RLS policies

3. **Image Upload Problems**
   - Check storage permissions
   - Verify file size limits
   - Ensure proper image format

4. **Real-time Sync Issues**
   - Check internet connection
   - Verify Supabase real-time settings
   - Review subscription configurations

### **Debug Mode**
Enable debug mode for detailed logging:
```dart
// In main.dart
debugShowCheckedModeBanner: true
```

## 📈 Performance Optimization

### **Caching Strategy**
- **Local Database**: SQLite for offline data
- **Image Caching**: Cached network images
- **API Response Caching**: Reduced network calls

### **Memory Management**
- **Controller Disposal**: Proper cleanup of text controllers
- **Image Compression**: Optimized image sizes
- **Lazy Loading**: Efficient list rendering

## 🔒 Security Features

### **Data Protection**
- **Encrypted Storage**: Sensitive data encryption
- **Secure Communication**: HTTPS/TLS for all API calls
- **Session Management**: Secure token handling

### **Access Control**
- **Role-based Permissions**: Granular access control
- **Authentication**: Multi-factor authentication support
- **Authorization**: API-level permission checks

## 🚀 Deployment

### **Android**
```bash
flutter build apk --release
flutter build appbundle --release
```

### **iOS**
```bash
flutter build ios --release
```

### **Web**
```bash
flutter build web --release
```

## 📊 Monitoring & Analytics

### **Error Tracking**
- **Crash Reporting**: Automatic crash detection
- **Error Logging**: Detailed error information
- **Performance Monitoring**: App performance metrics

### **User Analytics**
- **Usage Statistics**: Feature usage tracking
- **Performance Metrics**: Response times and efficiency
- **User Behavior**: Interaction patterns

## 🤝 Contributing

### **Development Guidelines**
1. Follow Flutter/Dart coding standards
2. Write comprehensive tests
3. Document new features
4. Follow the existing code structure

### **Code Review Process**
1. Create feature branches
2. Submit pull requests
3. Code review and testing
4. Merge to main branch

## 📄 License

This project is proprietary software. All rights reserved.

## 📞 Support

For technical support or questions:
- **Email**: support@autofix.com
- **Documentation**: [Internal Wiki]
- **Issue Tracking**: [Internal System]

## 🔄 Version History

### **v1.0.0** (Current)
- Initial release
- Complete workflow implementation
- Multi-role support
- Real-time synchronization
- Comprehensive reporting

### **Future Releases**
- Advanced analytics
- Mobile app for customers
- Integration with external systems
- Enhanced reporting features

---

**AutoFix** - Streamlining vehicle service management with modern technology and intuitive design.