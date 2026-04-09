String getCookieFromSetCookieHeader(String setCookieHeader) {
  final cookies = setCookieHeader.split(';');
  String cookieOut = "";

  for(final cookie in cookies) {
    final cookieParts = cookie.split(',');
    for(final part in cookieParts) {
      if(part.startsWith("SID=") || part.startsWith(".ASPXAUTH=")) {
        cookieOut += "${part.trim()}; ";
      }
    }
  }

  return cookieOut;
}