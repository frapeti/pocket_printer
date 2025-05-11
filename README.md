# PAX Printer App

A Flutter application for printing images and QR codes using PAX POSNET A910 printers. This app provides a simple and intuitive interface for managing your printing needs.

## Features

- Print images from your device's gallery
- Generate and print QR codes
- Simple and user-friendly interface
- Support for PAX POSNET A910 printer
- Image optimization for better print quality
- System-level printing service for Android 6.0+

## Requirements

- Flutter SDK ^3.7.2
- PAX POSNET A910 printer device
- Android 6.0+ device

## Dependencies

- flutter_pax_printer_utility: ^0.1.4
- image_picker: ^1.0.7
- permission_handler: ^11.3.1

## Getting Started

1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Connect your PAX POSNET A910 printer device
4. Run the app using `flutter run`

## Usage

1. Launch the app
2. Select an image from your gallery or generate a QR code
3. Click the print button to send the content to your PAX printer
4. Wait for the printing process to complete

## Android Print Service

The app includes a system-level print service for Android 6.0 and above. This allows the app to:
- Appear in the system print menu
- Handle print jobs from other apps
- Manage print queue and status
- Support multiple print formats

## Permissions

The app requires the following permissions:
- Storage access (for selecting images from gallery)
- Print service permission (for Android print service)

## Support

For issues and feature requests, please create an issue in the repository.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
