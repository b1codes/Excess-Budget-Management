import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SupabaseClient supabase;

  AuthBloc({required this.supabase}) : super(AuthInitial()) {
    on<AuthCheckRequested>((event, emit) async {
      final session = supabase.auth.currentSession;
      if (session != null) {
        emit(AuthAuthenticated(session.user));
      } else {
        emit(AuthUnauthenticated());
      }
    });

    on<AuthLoginRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        final response = await supabase.auth.signInWithPassword(
          email: event.email,
          password: event.password,
        );
        if (response.user != null) {
          emit(AuthAuthenticated(response.user!));
        } else {
          emit(const AuthError('Login failed.'));
        }
      } catch (e) {
        emit(AuthError(e.toString()));
      }
    });

    on<AuthSignupRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        final response = await supabase.auth.signUp(
          email: event.email,
          password: event.password,
        );
        if (response.user != null) {
          emit(AuthAuthenticated(response.user!));
        } else {
          emit(const AuthError('Signup failed.'));
        }
      } catch (e) {
        emit(AuthError(e.toString()));
      }
    });

    on<AuthLogoutRequested>((event, emit) async {
      emit(AuthLoading());
      await supabase.auth.signOut();
      emit(AuthUnauthenticated());
    });
  }
}
