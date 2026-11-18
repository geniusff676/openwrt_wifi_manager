/// Connection details for the router. Held in memory only; the password is never persisted.
class RouterConfig {
  const RouterConfig({
    required this.host,
    required this.password,
    this.port = 22,
    this.username = 'root',
  });

  final String host;
  final int port;
  final String username;
  final String password;

  // Deliberately omits the password so it can never leak into logs.
  @override
  String toString() => 'RouterConfig($username@$host:$port)';
}
