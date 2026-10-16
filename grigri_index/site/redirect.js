// Runs first, in <head>: a climber already signed in (the app's session
// token, kept by shared_preferences in this origin's local storage) or a
// link with a query string goes straight to the app, as / always did.
(function () {
  let signedIn = false;
  try {
    signedIn = !!localStorage.getItem('flutter.grigri.session');
  } catch (e) {
    // Storage blocked: show the landing page.
  }
  if (signedIn || location.search) location.replace('/app/' + location.search);
})();
