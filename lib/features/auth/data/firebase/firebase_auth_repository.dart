import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/enums/user_role.dart';
import '../../models/tatame_user.dart';
import '../../repository/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth firebaseAuth;
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  FirebaseAuthRepository({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       firestore = firestore ?? FirebaseFirestore.instance,
       functions =
           functions ??
           FirebaseFunctions.instanceFor(region: 'southamerica-east1');

  @override
  Future<TatameUser?> login({
    required String email,
    required String password,
  }) async {
    final credential = await firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final firebaseUser = credential.user;

    if (firebaseUser == null) {
      return null;
    }

    debugPrint('==========================');
    debugPrint('LOGIN FIREBASE REALIZADO');
    debugPrint('UID: ${firebaseUser.uid}');
    debugPrint('E-MAIL: ${firebaseUser.email}');
    debugPrint('==========================');

    return _loadTatameUser(firebaseUser.uid);
  }

  @override
  Future<TatameUser?> restoreSession() async {
    final firebaseUser = firebaseAuth.currentUser;

    if (firebaseUser == null) {
      return null;
    }

    debugPrint('==========================');
    debugPrint('RESTAURANDO SESSÃO');
    debugPrint('UID: ${firebaseUser.uid}');
    debugPrint('==========================');

    try {
      return await _loadTatameUser(firebaseUser.uid);
    } catch (_) {
      await firebaseAuth.signOut();
      return null;
    }
  }

  Future<TatameUser?> _loadTatameUser(String uid) async {
    final userSnapshot = await firestore.collection('users').doc(uid).get();

    if (!userSnapshot.exists) {
      await firebaseAuth.signOut();

      throw StateError(
        'O usuário está autenticado, mas não possui cadastro no Tatame+.',
      );
    }

    final userData = userSnapshot.data();

    if (userData == null) {
      await firebaseAuth.signOut();

      throw StateError('Não foi possível carregar os dados deste usuário.');
    }

    if (userData['isActive'] != true) {
      await firebaseAuth.signOut();

      if (userData['registrationStatus'] == 'pending') {
        throw StateError('Seu cadastro está aguardando aprovação da academia.');
      }

      throw StateError('Este usuário não está ativo no Tatame+.');
    }

    final academyId = await _findUserAcademy(uid);

    if (academyId == null) {
      await firebaseAuth.signOut();

      throw StateError('Este usuário não está vinculado a nenhuma academia.');
    }

    final memberSnapshot = await firestore
        .collection('academies')
        .doc(academyId)
        .collection('members')
        .doc(uid)
        .get();

    final memberData = memberSnapshot.data();

    if (!memberSnapshot.exists ||
        memberData == null ||
        memberData['status'] != 'active') {
      await firebaseAuth.signOut();

      throw StateError(
        'O vínculo deste usuário com a academia não está ativo.',
      );
    }

    final roles = _parseRoles(memberData['roles']);

    if (roles.isEmpty) {
      await firebaseAuth.signOut();

      throw StateError('Este usuário não possui perfil de acesso autorizado.');
    }

    return TatameUser(
      id: uid,
      academyId: academyId,
      name: userData['displayName'] as String? ?? 'Usuário',
      email: userData['email'] as String? ?? '',
      roles: roles,
      isActive: true,
    );
  }

  Future<String?> _findUserAcademy(String uid) async {
    const knownAcademies = ['gracie-barra-neves'];

    for (final academyId in knownAcademies) {
      final memberSnapshot = await firestore
          .collection('academies')
          .doc(academyId)
          .collection('members')
          .doc(uid)
          .get();

      if (memberSnapshot.exists) {
        return academyId;
      }
    }

    return null;
  }

  List<UserRole> _parseRoles(dynamic rawRoles) {
    if (rawRoles is! Map) {
      return const [];
    }

    final roles = <UserRole>[];

    if (rawRoles['admin'] == true) roles.add(UserRole.admin);
    if (rawRoles['partner'] == true) roles.add(UserRole.partner);
    if (rawRoles['teacher'] == true) roles.add(UserRole.teacher);
    if (rawRoles['student'] == true) roles.add(UserRole.student);
    if (rawRoles['guardian'] == true) roles.add(UserRole.guardian);

    return roles;
  }

  @override
  Future<void> register({
    required String displayName,
    required String email,
    required String password,
    String? phone,
  }) async {
    final callable = functions.httpsCallable('selfRegisterUser');

    try {
      await callable.call<Map<String, dynamic>>({
        'displayName': displayName.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
        'phone': phone?.trim(),
      });
    } on FirebaseFunctionsException catch (error) {
      switch (error.code) {
        case 'already-exists':
          throw const RegistrationException(
            'Já existe uma conta cadastrada com este e-mail.',
          );

        case 'invalid-argument':
          throw RegistrationException(
            error.message ?? 'Os dados informados são inválidos.',
          );

        case 'unavailable':
          throw const RegistrationException(
            'O serviço está indisponível. Tente novamente em instantes.',
          );

        case 'deadline-exceeded':
          throw const RegistrationException(
            'A solicitação demorou demais. Verifique sua conexão e tente novamente.',
          );

        default:
          throw RegistrationException(
            error.message ?? 'Não foi possível solicitar o cadastro.',
          );
      }
    }
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedEmail.isEmpty) {
      throw const PasswordManagementException(
        'Informe o e-mail usado no cadastro.',
      );
    }

    try {
      await firebaseAuth.setLanguageCode('pt-BR');
      await firebaseAuth.sendPasswordResetEmail(email: normalizedEmail);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-not-found') {
        return;
      }

      switch (error.code) {
        case 'invalid-email':
          throw const PasswordManagementException(
            'Informe um endereço de e-mail válido.',
          );
        case 'too-many-requests':
          throw const PasswordManagementException(
            'Muitas tentativas foram realizadas. Aguarde alguns minutos.',
          );
        case 'network-request-failed':
          throw const PasswordManagementException(
            'Não foi possível conectar. Verifique sua internet.',
          );
        default:
          throw const PasswordManagementException(
            'Não foi possível enviar a redefinição de senha.',
          );
      }
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = firebaseAuth.currentUser;
    final email = user?.email;

    if (user == null || email == null || email.isEmpty) {
      throw const PasswordManagementException(
        'Sua sessão não está disponível. Entre novamente.',
      );
    }

    if (currentPassword.isEmpty) {
      throw const PasswordManagementException('Informe sua senha atual.');
    }

    if (newPassword.length < 8) {
      throw const PasswordManagementException(
        'A nova senha precisa ter pelo menos 8 caracteres.',
      );
    }

    if (currentPassword == newPassword) {
      throw const PasswordManagementException(
        'A nova senha deve ser diferente da senha atual.',
      );
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (error) {
      switch (error.code) {
        case 'wrong-password':
        case 'invalid-credential':
          throw const PasswordManagementException(
            'A senha atual está incorreta.',
          );
        case 'weak-password':
          throw const PasswordManagementException(
            'A nova senha é muito fraca.',
          );
        case 'requires-recent-login':
          throw const PasswordManagementException(
            'Entre novamente no aplicativo antes de trocar a senha.',
          );
        case 'too-many-requests':
          throw const PasswordManagementException(
            'Muitas tentativas foram realizadas. Aguarde alguns minutos.',
          );
        case 'network-request-failed':
          throw const PasswordManagementException(
            'Não foi possível conectar. Verifique sua internet.',
          );
        default:
          throw const PasswordManagementException(
            'Não foi possível alterar a senha.',
          );
      }
    }
  }

  @override
  Future<void> logout() async {
    await firebaseAuth.signOut();
  }
}
