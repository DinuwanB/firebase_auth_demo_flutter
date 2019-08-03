import 'dart:async';

import 'package:firebase_auth_demo_flutter/app/sign_in/validator.dart';
import 'package:firebase_auth_demo_flutter/common_widgets/form_submit_button.dart';
import 'package:firebase_auth_demo_flutter/common_widgets/platform_alert_dialog.dart';
import 'package:firebase_auth_demo_flutter/common_widgets/platform_exception_alert_dialog.dart';
import 'package:firebase_auth_demo_flutter/constants/constants.dart';
import 'package:firebase_auth_demo_flutter/constants/strings.dart';
import 'package:firebase_auth_demo_flutter/services/auth_service.dart';
import 'package:firebase_auth_demo_flutter/services/email_secure_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info/package_info.dart';
import 'package:provider/provider.dart';

class EmailLinkSignInPage extends StatefulWidget {
  const EmailLinkSignInPage({
    Key key,
    @required this.emailStore,
    @required this.authService,
  }) : super(key: key);
  final EmailSecureStore emailStore;
  final AuthService authService;

  static Future<void> show(BuildContext context) async {
    final EmailSecureStore emailStore = Provider.of<EmailSecureStore>(context);
    final AuthService authService = Provider.of<AuthService>(context);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => EmailLinkSignInPage(
          emailStore: emailStore,
          authService: authService,
        ),
      ),
    );
  }

  @override
  _EmailLinkSignInPageState createState() => _EmailLinkSignInPageState();
}

class _EmailLinkSignInPageState extends State<EmailLinkSignInPage> {
  String _email;
  bool _loading = false;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final RegexValidator _emailSubmitValidator = EmailSubmitRegexValidator();

  final TextEditingController _emailController = TextEditingController();

  StreamSubscription<User> _onAuthStateChangedSubscription;
  @override
  void initState() {
    super.initState();
    // Get email from store initially
    widget.emailStore.getEmail().then((String email) {
      _email = email ?? '';
      _emailController.value = TextEditingValue(text: _email);
    });
    // Dismiss page if a user is signed in
    _onAuthStateChangedSubscription = widget.authService.onAuthStateChanged.listen((User user) {
      if (user != null) {
        Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
      }
    });
  }

  @override
  void dispose() {
    _onAuthStateChangedSubscription?.cancel();
    super.dispose();
  }

  Future<void> _sendEmailLink() async {
    setState(() => _loading = true);
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      // Save to email store
      await widget.emailStore.setEmail(_email);
      // Send link
      await widget.authService.sendSignInWithEmailLink(
        email: _email,
        url: Constants.firebaseProjectURL,
        handleCodeInApp: true,
        iOSBundleID: packageInfo.packageName,
        androidPackageName: packageInfo.packageName,
        androidInstallIfNotAvailable: true,
        androidMinimumVersion: '21',
      );
      // Tell user we sent an email
      PlatformAlertDialog(
        title: Strings.checkYourEmail,
        content: Strings.activationLinkSent(_email),
        defaultActionText: Strings.ok,
      ).show(context);
    } on PlatformException catch (e) {
      PlatformExceptionAlertDialog(
        title: Strings.errorSendingEmail,
        exception: e,
      ).show(context);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _validateAndSubmit() async {
    if (_formKey.currentState.validate()) {
      _formKey.currentState.save();
      await _sendEmailLink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 2.0,
        title: Text(Strings.yourEmail),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Card(
            child: Padding(
          padding: EdgeInsets.all(16.0),
          child: _buildForm(),
        )),
      ),
      backgroundColor: Colors.grey[200],
    );
  }

  Widget _buildForm() {
    final TextStyle hintStyle = TextStyle(fontSize: 18.0, color: Colors.grey[400]);
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(Strings.submitEmailAddressLink),
          SizedBox(height: 24.0),
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: Strings.emailLabel,
              hintText: Strings.emailHint,
              hintStyle: hintStyle,
            ),
            enabled: !_loading,
            keyboardType: TextInputType.emailAddress,
            validator: (String value) {
              return _emailSubmitValidator.isValid(value) ? null : Strings.invalidEmailErrorText;
            },
            inputFormatters: <TextInputFormatter>[
              ValidatorInputFormatter(editingValidator: EmailEditingRegexValidator()),
            ],
            autocorrect: true,
            keyboardAppearance: Brightness.light,
            textCapitalization: TextCapitalization.none,
            textInputAction: TextInputAction.done,
            onSaved: (String email) => _email = email,
            onEditingComplete: _validateAndSubmit,
          ),
          SizedBox(height: 16.0),
          FormSubmitButton(
            onPressed: _loading ? null : _validateAndSubmit,
            loading: _loading,
            text: Strings.sendActivationLink,
          ),
          SizedBox(height: 12.0),
        ],
      ),
    );
  }
}