// Chapter 29: three ways a Dart client can treat a server's certificate.
// Usage: dart run client.dart <port>
import 'dart:convert';
import 'dart:io';

Future<String> fetch(HttpClient client, int port) async {
  try {
    final request = await client.getUrl(Uri.parse('https://127.0.0.1:$port/'));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    return 'connected, status ${response.statusCode}, body: $body';
  } on HandshakeException catch (e) {
    // The operating system's own words are in osError (for example
    // CERTIFICATE_VERIFY_FAILED); the plain message is only "Handshake error".
    return 'refused: HandshakeException: ${e.message}; ${e.osError?.message}';
  } on TlsException catch (e) {
    return 'refused: ${e.runtimeType}: ${e.message}';
  } finally {
    client.close();
  }
}

Future<void> main(List<String> args) async {
  final port = int.parse(args.first);

  // 1. The default: the certificate must chain to a trusted authority. A
  //    self-signed certificate does not, so the connection is refused.
  print('1. default client:            ${await fetch(HttpClient(), port)}');

  // 2. The dangerous shortcut seen in many tutorials: accept every certificate.
  //    This turns TLS into encryption to *anyone*, including an attacker in the
  //    middle. Never ship it.
  final careless = HttpClient()..badCertificateCallback = (cert, host, p) => true;
  print('2. accept-everything callback: ${await fetch(careless, port)}');

  // 3. The right way to trust a development certificate: trust exactly that
  //    certificate, and nothing else.
  final context = SecurityContext(withTrustedRoots: false)
    ..setTrustedCertificates('cert.pem');
  print('3. trust only cert.pem:        ${await fetch(HttpClient(context: context), port)}');
}
