import 'dart:async';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixam_mart_delivery/common/widgets/code_picker_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_snackbar_widget.dart';
import 'package:sixam_mart_delivery/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart_delivery/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart_delivery/helper/route_helper.dart';
import 'package:sixam_mart_delivery/util/app_constants.dart';
import 'package:sixam_mart_delivery/util/styles.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  int _clickCount = 0;
  DateTime? _lastClickTime;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _otpFocus = FocusNode();

  String? _countryDialCode;
  String? _countryCode;

  // Estado del flujo: 1 = Ingresar Teléfono, 2 = Ingresar OTP
  int _currentStep = 1;

  // Temporizador para reenviar OTP
  Timer? _resendTimer;
  int _resendSeconds = 30;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    final configModel = Get.find<SplashController>().configModel;
    _countryDialCode =
        Get.find<AuthController>().getUserCountryDialCode().isNotEmpty
            ? Get.find<AuthController>().getUserCountryDialCode()
            : (configModel != null
                ? CountryCode.fromCountryCode(configModel.country!).dialCode
                : '+52');
    _countryCode = Get.find<AuthController>().getUserCountryCode().isNotEmpty
        ? Get.find<AuthController>().getUserCountryCode()
        : (configModel != null
            ? CountryCode.fromCountryCode(configModel.country!).code
            : 'MX');

    _phoneController.text = Get.find<AuthController>().getUserNumber();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    _phoneFocus.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _resendSeconds = 30;
      _canResend = false;
    });
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() {
          _canResend = true;
        });
      } else {
        setState(() {
          _resendSeconds--;
        });
      }
    });
  }

  void _showEnvironmentSelector(BuildContext context) {
    final TextEditingController pinController = TextEditingController();
    Get.dialog(
      AlertDialog(
        title: const Text('Código de Acceso'),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: 'Ingresa el PIN de seguridad',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (pinController.text == '2026') {
                Get.back();
                _showSelectorDialog(context);
              } else {
                showCustomSnackBar('PIN incorrecto', isError: true);
              }
            },
            child: const Text('Validar'),
          ),
        ],
      ),
    );
  }

  void _showSelectorDialog(BuildContext context) {
    final prefs = Get.find<SharedPreferences>();
    final currentUrl =
        prefs.getString('tootli_base_url') ?? 'https://tootli.mx';

    Get.dialog(
      AlertDialog(
        title: const Text('Seleccionar Entorno'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Producción'),
              subtitle: const Text('https://tootli.mx'),
              trailing: currentUrl == 'https://tootli.mx'
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () => _saveEnv('https://tootli.mx'),
            ),
            ListTile(
              title: const Text('Sandbox (Staging)'),
              subtitle: const Text('https://dev-api.tootli.mx'),
              trailing: currentUrl == 'https://dev-api.tootli.mx'
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () => _saveEnv('https://dev-api.tootli.mx'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveEnv(String url) async {
    final prefs = Get.find<SharedPreferences>();
    await prefs.setString('tootli_base_url', url);
    await prefs.remove(AppConstants.token);

    Get.back();
    showCustomSnackBar('Cambiando entorno a: $url', isError: false);

    Future.delayed(const Duration(seconds: 1), () {
      Get.offAllNamed(RouteHelper.splash);
    });
  }

  void _onSendCode(AuthController authController) {
    String phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      showCustomSnackBar('Ingresa tu número de teléfono', isError: true);
      return;
    }

    String fullPhone = '$_countryDialCode$phone';
    authController.sendOtp(fullPhone).then((status) {
      if (status.isSuccess) {
        showCustomSnackBar(status.message ?? 'Código enviado', isError: false);
        setState(() {
          _currentStep = 2;
        });
        _startResendTimer();
      } else {
        showCustomSnackBar(status.message ?? 'Error al enviar OTP', isError: true);
      }
    });
  }

  void _onVerifyCode(AuthController authController) {
    String phone = _phoneController.text.trim();
    String fullPhone = '$_countryDialCode$phone';
    String otp = _otpController.text.trim();

    if (otp.isEmpty || otp.length < 4) {
      showCustomSnackBar('Ingresa el código completo de verificación', isError: true);
      return;
    }

    authController.verifyOtp(fullPhone, otp).then((status) {
      if (status.isSuccess) {
        if (status.isRegistered == true) {
          // Usuario registrado previamente -> Inicia sesión directo
          showCustomSnackBar('¡Bienvenido de vuelta!', isError: false);
          Get.offAllNamed(RouteHelper.getInitialRoute());
        } else {
          // Usuario NO registrado -> Pasa a subir documentos y KYC
          showCustomSnackBar('Número verificado. Completa tu registro.', isError: false);
          Get.offAllNamed(RouteHelper.getDmKycRoute(), arguments: {
            'phone': fullPhone,
          });
        }
      } else {
        showCustomSnackBar(status.message ?? 'Código de verificación incorrecto', isError: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: GetBuilder<AuthController>(
            builder: (authController) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  // Header Icono de Vehículo (Boton Oculto para Selector de Entorno)
                  GestureDetector(
                    onTap: () {
                      final now = DateTime.now();
                      if (_lastClickTime == null ||
                          now.difference(_lastClickTime!) >
                              const Duration(seconds: 2)) {
                        _clickCount = 1;
                      } else {
                        _clickCount++;
                      }
                      _lastClickTime = now;
                      if (_clickCount >= 5) {
                        _clickCount = 0;
                        _showEnvironmentSelector(context);
                      }
                    },
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFF006837),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF006837).withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.directions_car_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Flujo Paso 1: Ingreso de Número
                  if (_currentStep == 1) ...[
                    // Título y Subtítulo
                    Text(
                      'Inicia sesión para\nempezar a conducir',
                      style: robotoBold.copyWith(
                        fontSize: 26,
                        height: 1.25,
                        color: const Color(0xFF003822),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Gestiona tus viajes y ganancias.',
                      style: robotoRegular.copyWith(
                        fontSize: 15,
                        color: const Color(0xFF64748B),
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Tarjeta de Input de Teléfono
                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          CodePickerWidget(
                            onChanged: (CountryCode countryCode) {
                              _countryDialCode = countryCode.dialCode;
                              _countryCode = countryCode.code;
                              setState(() {});
                            },
                            initialSelection: _countryCode ?? 'MX',
                            favorite: [_countryCode ?? 'MX'],
                            showDropDownButton: true,
                            textStyle: robotoRegular.copyWith(
                              fontSize: 15,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Container(
                            height: 24,
                            width: 1,
                            color: const Color(0xFFCBD5E1),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              focusNode: _phoneFocus,
                              keyboardType: TextInputType.phone,
                              style: robotoMedium.copyWith(
                                fontSize: 16,
                                color: const Color(0xFF0F172A),
                              ),
                              cursorColor: const Color(0xFF006837),
                              decoration: const InputDecoration(
                                hintText: 'Ingresa tu número de teléfono',
                                hintStyle: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 15,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onSubmitted: (_) => _onSendCode(authController),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Botón Enviar Código
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: authController.isLoading
                            ? null
                            : () => _onSendCode(authController),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Color(0xFF006837),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: authController.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF006837),
                                  ),
                                ),
                              )
                            : Text(
                                'Enviar código',
                                style: robotoBold.copyWith(
                                  fontSize: 16,
                                  color: const Color(0xFF006837),
                                ),
                              ),
                      ),
                    ),
                  ],

                  // Flujo Paso 2: Verificación OTP
                  if (_currentStep == 2) ...[
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _currentStep = 1;
                            });
                          },
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Verificación OTP',
                          style: robotoBold.copyWith(
                            fontSize: 20,
                            color: const Color(0xFF003822),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Ingresa el código enviado a',
                      style: robotoRegular.copyWith(
                        fontSize: 15,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_countryDialCode ${_phoneController.text}',
                      style: robotoBold.copyWith(
                        fontSize: 18,
                        color: const Color(0xFF0F172A),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Campo de Código OTP
                    Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF006837),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: TextField(
                          controller: _otpController,
                          focusNode: _otpFocus,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: robotoBold.copyWith(
                            fontSize: 22,
                            letterSpacing: 8.0,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLength: 6,
                          cursorColor: const Color(0xFF006837),
                          decoration: const InputDecoration(
                            hintText: '• • • • • •',
                            hintStyle: TextStyle(
                              color: Color(0xFFCBD5E1),
                              letterSpacing: 4.0,
                            ),
                            border: InputBorder.none,
                            counterText: '',
                            isDense: true,
                          ),
                          onSubmitted: (_) => _onVerifyCode(authController),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Reenviar Código
                    Center(
                      child: TextButton(
                        onPressed: _canResend ? () => _onSendCode(authController) : null,
                        child: Text(
                          _canResend
                              ? 'Reenviar código OTP'
                              : 'Reenviar código en $_resendSeconds seg',
                          style: robotoMedium.copyWith(
                            fontSize: 14,
                            color: _canResend ? const Color(0xFF006837) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Botón Verificar Código
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: authController.isLoading
                            ? null
                            : () => _onVerifyCode(authController),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF006837),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: authController.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                'Verificar e iniciar',
                                style: robotoBold.copyWith(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],

                  const Spacer(),

                  // Footer: Términos y Condiciones
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: robotoRegular.copyWith(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                            height: 1.4,
                          ),
                          children: const [
                            TextSpan(text: 'Al registrarte, aceptas los '),
                            TextSpan(
                              text: 'Términos',
                              style: TextStyle(
                                color: Color(0xFF006837),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(text: ' y la '),
                            TextSpan(
                              text: 'Política\nde privacidad',
                              style: TextStyle(
                                color: Color(0xFF006837),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
