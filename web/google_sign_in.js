// This file initializes the Google Sign-In API for web
window.googleSignInInit = function() {
  // Initialize Google Sign-In API
  if (typeof gapi !== 'undefined') {
    gapi.load('auth2', function() {
      gapi.auth2.init({
        client_id: '903962440902-9s7u72p3p75e4218ni8ookv29g9dv8fg.apps.googleusercontent.com',
        scope: 'https://www.googleapis.com/auth/drive.file'
      });
    });
  }
};
