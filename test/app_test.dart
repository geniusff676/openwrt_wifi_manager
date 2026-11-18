import 'package:flutter_test/flutter_test.dart';
import 'package:openwrt_wifi_manager/main.dart';
import 'package:openwrt_wifi_manager/models/router_config.dart';
import 'package:openwrt_wifi_manager/services/mock_ssh_service.dart';
import 'package:openwrt_wifi_manager/services/openwrt_service.dart';
import 'package:openwrt_wifi_manager/services/ssh_service.dart';
import 'package:openwrt_wifi_manager/utils/validators.dart';

const _cfg = RouterConfig(host: '192.168.1.1', password: 'x');
MockSshService _mock() => MockSshService(delay: Duration.zero);

void main() {
  test('application entrypoint compiles', () {
    expect(WifiManagerApp, isA<Type>());
  });

  test('validators', () {
    expect(Validators.ssid(''), isNotNull);
    expect(Validators.ssid("a'b"), isNotNull);
    expect(Validators.ssid(r'$(reboot)'), isNotNull);
    expect(Validators.ssid('Home WiFi'), isNull);
    expect(Validators.password('short'), isNotNull);
    expect(Validators.password('good-password-1'), isNull);
    expect(Validators.confirm('a', 'b'), isNotNull);
  });

  test('shellQuote yields one literal word', () {
    expect(OpenWrtService.shellQuote("a'b"), r"'a'\''b'");
  });

  test('apply changes only ssid and key', () async {
    final m = _mock();
    final steps = <ApplyStep>[];
    await OpenWrtService(m).applyWifi(_cfg, 'New Name', 'newpass1234', steps.add);
    expect(m.liveValue('ssid'), 'New Name');
    expect(m.liveValue('key'), 'newpass1234');
    expect(m.liveValue('mode'), 'ap');
    expect(steps.last, ApplyStep.done);
  });

  test('missing or management section is refused', () async {
    for (final s in ['nope', 'default_radio0']) {
      expect(
        OpenWrtService(_mock(), section: s).verify(_cfg),
        throwsA(isA<RouterException>()),
      );
    }
  });

  test('bad credentials surface as authFailed', () {
    expect(
      OpenWrtService(_mock()).verify(const RouterConfig(host: '192.168.1.1', password: 'wrong')),
      throwsA(isA<RouterException>().having((e) => e.kind, 'kind', RouterErrorKind.authFailed)),
    );
  });
}
