import 'dart:html' as web;

void clearWebUrl() {
  final uri = Uri.parse(web.window.location.href);
  final nuevaUrl = uri.replace(path: '/', query: '').toString();
  web.window.history.replaceState(null, '', nuevaUrl);
}

bool isMobileWeb() {
  final ua = web.window.navigator.userAgent.toLowerCase();
  return ua.contains('iphone') || ua.contains('android');
}
