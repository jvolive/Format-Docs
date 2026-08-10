import 'package:flutter/material.dart';
import 'package:format_docs/features/home/home_page.dart';
import 'package:format_docs/features/supabase/auth/auth_view_model.dart';
import 'package:format_docs/initializer.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const routeName = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final AuthViewModel _authViewModel;
  bool _navigatedToHome = false;

  @override
  void initState() {
    super.initState();
    _authViewModel = getIt<AuthViewModel>();
    _authViewModel.addListener(_handleAuthStateChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleAuthStateChange();
    });
  }

  @override
  void dispose() {
    _authViewModel.removeListener(_handleAuthStateChange);
    super.dispose();
  }

  void _handleAuthStateChange() {
    if (!mounted) return;

    if (_authViewModel.status == AuthStatus.authenticated) {
      if (_navigatedToHome) return;

      _navigatedToHome = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(HomePage.routeName);
      });
    } else {
      _navigatedToHome = false;
    }
  }

  Future<void> _onSignInPressed() async {
    await _authViewModel.signInWithGoogle();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F2),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 860;

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 48 : 24,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: isWide
                      ? Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Align(
                                alignment: Alignment.center,
                                child: _SignInPanel(
                                  authViewModel: _authViewModel,
                                  onSignInPressed: _onSignInPressed,
                                ),
                              ),
                            ),
                            const SizedBox(width: 64),
                            const Expanded(flex: 6, child: _BrandPanel()),
                          ],
                        )
                      : _SignInPanel(
                          authViewModel: _authViewModel,
                          onSignInPressed: _onSignInPressed,
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SignInPanel extends StatelessWidget {
  final AuthViewModel authViewModel;
  final VoidCallback onSignInPressed;

  const _SignInPanel({
    required this.authViewModel,
    required this.onSignInPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: ListenableBuilder(
        listenable: authViewModel,
        builder: (context, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _AppMark(),
              const SizedBox(height: 34),
              Text(
                'Sign in',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Use your Google account to review and format documents.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: authViewModel.isLoading ? null : onSignInPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF111111),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(
                    0xFF111111,
                  ).withValues(alpha: 0.56),
                  disabledForegroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: authViewModel.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Image.asset(
                        'assets/icons/google.png',
                        width: 20,
                        height: 20,
                      ),
                label: Text(
                  authViewModel.isLoading
                      ? 'Connecting...'
                      : 'Continue with Google',
                ),
              ),
              if (authViewModel.errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    authViewModel.errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colorScheme.onErrorContainer),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AppMark extends StatelessWidget {
  const _AppMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomPaint(size: const Size(32, 28), painter: _LogoMarkPainter()),
        const SizedBox(height: 8),
        Text(
          'Doc Reviewer',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.76,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 660),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 42,
              offset: const Offset(0, 24),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _BrandPanelPainter())),
            Padding(
              padding: const EdgeInsets.all(56),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 3),
                  Text(
                    'Doc Reviewer',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Welcome to Doc Reviewer',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Review documents, manage rules, and clean formatted text in one focused workspace.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.74),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 48),
                  const _FeatureCallout(),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCallout extends StatelessWidget {
  const _FeatureCallout();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF333333),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Keep every review clear and consistent',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Apply reusable rules and export cleaner documents without leaving the app.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width * 0.5, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.72, size.height)
      ..lineTo(size.width * 0.5, size.height * 0.42)
      ..lineTo(size.width * 0.28, size.height)
      ..lineTo(0, size.height)
      ..close();

    final cutout = Path()
      ..moveTo(size.width * 0.5, size.height * 0.53)
      ..lineTo(size.width * 0.62, size.height * 0.78)
      ..lineTo(size.width * 0.38, size.height * 0.78)
      ..close();

    canvas.drawPath(
      Path.combine(PathOperation.difference, path, cutout),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BrandPanelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final logoPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeJoin = StrokeJoin.miter;

    final logo = Path()
      ..moveTo(size.width * 0.22, size.height * 0.34)
      ..lineTo(size.width * 0.40, size.height * 0.08)
      ..lineTo(size.width * 0.60, size.height * 0.34);
    canvas.drawPath(logo, logoPaint);

    final accentPaint = Paint()
      ..color = const Color(0xFFB5C2BC).withValues(alpha: 0.72)
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(size.width * 0.78, -20),
      Offset(size.width + 36, size.height * 0.08),
      accentPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.56, size.height * 0.44),
      Offset(size.width + 20, size.height * 0.06),
      accentPaint..color = const Color(0xFF59605F).withValues(alpha: 0.9),
    );
    canvas.drawLine(
      Offset(-20, size.height * 0.78),
      Offset(size.width * 0.42, size.height * 0.52),
      accentPaint..color = const Color(0xFF55609A).withValues(alpha: 0.68),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
