import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/core/constants/app_constants.dart';
import 'package:xev9s_app/core/utils/validators.dart';

void main() {
  group('Validators', () {
    test('required validates null, empty, whitespace and valid values', () {
      expect(Validators.required(null), equals('This field is required.'));
      expect(Validators.required(''), equals('This field is required.'));
      expect(Validators.required('   '), equals('This field is required.'));
      expect(Validators.required('null', 'Name'), isNull);
      expect(Validators.required(' Valid ', 'Username'), isNull);
    });

    test('email validates correctly with permissive rules', () {
      expect(Validators.email(null), equals('Email is required.'));
      expect(Validators.email(''), equals('Email is required.'));
      expect(Validators.email('   '), equals('Email is required.'));
      expect(Validators.email('plainaddress'), equals("Please include an '@' in the email address (e.g., name@example.com)."));
      expect(Validators.email('@missinglocal.com'), equals("Please enter a username before the '@' (e.g., name@example.com)."));
      expect(Validators.email('missingdomain@'), equals("Please enter a domain after the '@' (e.g., example.com)."));
      expect(Validators.email('two@@at.com'), equals("Email address can only contain one '@'."));
      expect(Validators.email('has space@domain.com'), equals('Email address cannot contain spaces.'));
      expect(Validators.email('domain@nodot'), equals("Please include a domain extension like '.com' (e.g., name@example.com)."));
      expect(Validators.email('user@.leadingdot.com'), equals('Please enter a valid domain (e.g., example.com).'));
      expect(Validators.email('user@trailingdot.'), equals('Please enter a valid domain (e.g., example.com).'));

      // Valid emails
      expect(Validators.email('owner@example.com'), isNull);
      expect(Validators.email('  user.name+tag@sub.domain.org  '), isNull);
    });

    test('minLength validates minimum length with and without trimming', () {
      expect(Validators.minLength(null, 5), equals('This field must be at least 5 characters.'));
      expect(Validators.minLength('abc', 5, fieldName: 'Field'), equals('Field must be at least 5 characters.'));
      expect(Validators.minLength('  abc  ', 5, trim: true), equals('This field must be at least 5 characters.'));
      expect(Validators.minLength('  abc  ', 5, trim: false), isNull);
      expect(Validators.minLength('12345', 5), isNull);
    });

    test('password validates length without trimming', () {
      expect(Validators.password(null), equals('Password is required.'));
      expect(Validators.password(''), equals('Password is required.'));
      expect(Validators.password('1234567'), equals('Password must be at least ${AppConstants.minPasswordLength} characters.'));
      expect(Validators.password('12345678'), isNull);
      // Spaces count towards length (passwords are untrimmed)
      expect(Validators.password('  345678'), isNull);
      // Exceeds max length
      final longPassword = 'a' * (AppConstants.maxPasswordLength + 1);
      expect(Validators.password(longPassword), equals('Password must not exceed ${AppConstants.maxPasswordLength} characters.'));
    });

    test('maxLength validates maximum length', () {
      expect(Validators.maxLength(null, 5), isNull);
      expect(Validators.maxLength('12345', 5), isNull);
      expect(Validators.maxLength('123456', 5, fieldName: 'Code'), equals('Code must not exceed 5 characters.'));
      expect(Validators.maxLength('  12345  ', 5, trim: true), isNull);
    });

    test('matches validates equality', () {
      expect(Validators.matches('secret', 'secret', 'Mismatch'), isNull);
      expect(Validators.matches('secret', 'different', 'Passwords do not match.'), equals('Passwords do not match.'));
      expect(Validators.matches(null, 'secret', 'Mismatch'), equals('Mismatch'));
    });

    test('digitsOnly validates numeric strings', () {
      expect(Validators.digitsOnly(null), isNull);
      expect(Validators.digitsOnly(''), isNull);
      expect(Validators.digitsOnly('123456'), isNull);
      expect(Validators.digitsOnly('  123456  '), isNull);
      expect(Validators.digitsOnly('123a56'), equals('Must contain only digits.'));
      expect(Validators.digitsOnly('-123'), equals('Must contain only digits.'));
      expect(Validators.digitsOnly('12 34'), equals('Must contain only digits.'));
    });

    test('exactLength validates exact length', () {
      expect(Validators.exactLength(null, 6), isNull);
      expect(Validators.exactLength('', 6), isNull);
      expect(Validators.exactLength('12345', 6), equals('Must be exactly 6 characters.'));
      expect(Validators.exactLength('1234567', 6), equals('Must be exactly 6 characters.'));
      expect(Validators.exactLength('123456', 6), isNull);
      expect(Validators.exactLength('  123456  ', 6), isNull);
    });
  });
}
