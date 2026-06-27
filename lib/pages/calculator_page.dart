// lib/pages/calculator_page.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  String _expression = '';
  String _result = '';
  bool _showError = false;

  void _onKeyPress(String value) {
    setState(() {
      _showError = false;
      if (value == 'C') {
        _expression = '';
        _result = '';
      } else if (value == '⌫') {
        if (_expression.isNotEmpty) {
          // Deleting multi-character scientific functions cleanly
          if (_expression.endsWith('sin(') ||
              _expression.endsWith('cos(') ||
              _expression.endsWith('tan(') ||
              _expression.endsWith('log(') ||
              _expression.endsWith('abs(')) {
            _expression = _expression.substring(0, _expression.length - 4);
          } else if (_expression.endsWith('asin(') ||
              _expression.endsWith('acos(') ||
              _expression.endsWith('atan(')) {
            _expression = _expression.substring(0, _expression.length - 5);
          } else if (_expression.endsWith('ln(')) {
            _expression = _expression.substring(0, _expression.length - 3);
          } else if (_expression.endsWith('√(')) {
            _expression = _expression.substring(0, _expression.length - 2);
          } else if (_expression.endsWith('^-1')) {
            _expression = _expression.substring(0, _expression.length - 3);
          } else {
            _expression = _expression.substring(0, _expression.length - 1);
          }
        }
      } else if (value == '=') {
        _evaluate();
      } else {
        _expression += value;
      }
    });
  }

  void _evaluate() {
    final trimmed = _expression.trim();
    
    // Check secret code bypass
    if (trimmed == '3625') {
      setState(() {
        _expression = '';
        _result = '';
      });
      Navigator.pushNamed(context, '/auth_gate');
      return;
    }

    if (trimmed.isEmpty) return;

    try {
      // Normalize expression for parsing
      String parsedExpr = trimmed
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .replaceAll('π', 'pi');

      // Auto-close missing parentheses (like Casio calculators do)
      int openCount = 0;
      int closeCount = 0;
      for (int i = 0; i < parsedExpr.length; i++) {
        if (parsedExpr[i] == '(') openCount++;
        if (parsedExpr[i] == ')') closeCount++;
      }
      if (openCount > closeCount) {
        parsedExpr += ')' * (openCount - closeCount);
      }

      final evaluator = MathEvaluator(parsedExpr);
      final evalResult = evaluator.parse();
      
      setState(() {
        if (evalResult.isInfinite || evalResult.isNaN) {
          _result = 'Error';
          _showError = true;
        } else {
          if (evalResult == evalResult.toInt()) {
            _result = evalResult.toInt().toString();
          } else {
            _result = evalResult.toStringAsFixed(8);
            // Trim trailing zeroes
            while (_result.endsWith('0')) {
              _result = _result.substring(0, _result.length - 1);
            }
            if (_result.endsWith('.')) {
              _result = _result.substring(0, _result.length - 1);
            }
          }
        }
      });
    } catch (e) {
      setState(() {
        _result = 'Error';
        _showError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      body: SafeArea(
        child: Column(
          children: [
            // Calculator Display Area
            Expanded(
              flex: isLandscape ? 2 : 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                alignment: Alignment.bottomRight,
                child: SingleChildScrollView(
                  reverse: true,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SelectableText(
                        _expression.isEmpty ? '0' : _expression,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w300,
                          color: Colors.white70,
                          letterSpacing: 1.0,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _result,
                        style: TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.bold,
                          color: _showError ? Colors.redAccent : theme.colorScheme.secondary,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(color: Color(0xFF22222A), height: 1),

            // Calculator Keypad
            Expanded(
              flex: isLandscape ? 6 : 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                color: const Color(0xFF141419),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildButtonRow(['C', '⌫', '(', ')', '÷']),
                    _buildButtonRow(['sin(', 'cos(', 'tan(', '^', '×']),
                    _buildButtonRow(['asin(', 'acos(', 'atan(', '√(', '-']),
                    _buildButtonRow(['7', '8', '9', 'log(', '+']),
                    _buildButtonRow(['4', '5', '6', 'ln(', '!']),
                    _buildButtonRow(['1', '2', '3', 'π', 'e']),
                    _buildButtonRow(['0', '.', 'abs(', '^-1', '=']),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButtonRow(List<String> keys) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: keys.map((key) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.all(3.0),
              child: _buildCalculatorButton(key),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCalculatorButton(String text) {
    final theme = Theme.of(context);
    
    bool isOperator = ['÷', '×', '-', '+', '='].contains(text);
    bool isFunction = ['sin(', 'cos(', 'tan(', 'asin(', 'acos(', 'atan(', 'log(', 'ln(', '√(', '^', '(', ')', '!', 'abs(', '^-1'].contains(text);
    bool isClear = ['C', '⌫'].contains(text);

    Color buttonColor;
    Color textColor = Colors.white;

    if (isOperator) {
      buttonColor = text == '=' ? theme.colorScheme.secondary : theme.colorScheme.primary;
      textColor = text == '=' ? Colors.black : Colors.white;
    } else if (isClear) {
      buttonColor = const Color(0xFF2C2C35);
      textColor = const Color(0xFFFFB300);
    } else if (isFunction) {
      buttonColor = const Color(0xFF1E1E24);
      textColor = theme.colorScheme.secondary;
    } else {
      buttonColor = const Color(0xFF24242C);
    }

    // Display labels formatting
    String displayLabel = text;
    if (text == 'sin(') displayLabel = 'sin';
    if (text == 'cos(') displayLabel = 'cos';
    if (text == 'tan(') displayLabel = 'tan';
    if (text == 'asin(') displayLabel = 'sin⁻¹';
    if (text == 'acos(') displayLabel = 'cos⁻¹';
    if (text == 'atan(') displayLabel = 'tan⁻¹';
    if (text == 'log(') displayLabel = 'log';
    if (text == 'ln(') displayLabel = 'ln';
    if (text == '√(') displayLabel = '√';
    if (text == 'abs(') displayLabel = 'abs';
    if (text == '!') displayLabel = 'x!';
    if (text == '^-1') displayLabel = 'x⁻¹';

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        foregroundColor: textColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: EdgeInsets.zero,
      ),
      onPressed: () => _onKeyPress(text),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          displayLabel,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Recursive Descent Math Parser for Casio FX-991ES Emulator
class MathEvaluator {
  final String expression;
  int _pos = -1;
  int _ch = 0;

  MathEvaluator(this.expression);

  void _nextChar() {
    _pos++;
    _ch = (_pos < expression.length) ? expression.codeUnitAt(_pos) : -1;
  }

  bool _eat(int charToEat) {
    while (_ch == 32) {
      _nextChar();
    }
    if (_ch == charToEat) {
      _nextChar();
      return true;
    }
    return false;
  }

  double parse() {
    _nextChar();
    double x = _parseExpression();
    if (_pos < expression.length) {
      throw FormatException("Unexpected character: ${String.fromCharCode(_ch)}");
    }
    return x;
  }

  double _parseExpression() {
    double x = _parseTerm();
    for (;;) {
      if (_eat(43)) {
        x += _parseTerm(); // +
      } else if (_eat(45)) {
        x -= _parseTerm(); // -
      } else {
        return x;
      }
    }
  }

  double _parseTerm() {
    double x = _parseFactor();
    for (;;) {
      if (_eat(42)) {
        x *= _parseFactor(); // *
      } else if (_eat(47)) {
        double divisor = _parseFactor();
        if (divisor == 0) throw ArgumentError("Division by zero");
        x /= divisor; // /
      } else {
        return x;
      }
    }
  }

  double _parseFactor() {
    if (_eat(43)) return _parseFactor(); // unary +
    if (_eat(45)) return -_parseFactor(); // unary -

    double x;
    int startPos = _pos;
    if (_eat(40)) { // (
      x = _parseExpression();
      if (!_eat(41)) throw const FormatException("Missing closing parenthesis");
    } else if ((_ch >= 48 && _ch <= 57) || _ch == 46) { // number
      while ((_ch >= 48 && _ch <= 57) || _ch == 46) {
        _nextChar();
      }
      x = double.parse(expression.substring(startPos, _pos));
    } else if ((_ch >= 97 && _ch <= 122) || _ch == 960 || _ch == 8730) { // word functions/constants, π, √
      while ((_ch >= 97 && _ch <= 122) || _ch == 960 || _ch == 8730) {
        _nextChar();
      }
      String name = expression.substring(startPos, _pos);
      if (name == 'pi' || name == 'π') {
        x = math.pi;
      } else if (name == 'e') {
        x = math.e;
      } else {
        if (!_eat(40)) throw FormatException("Missing opening parenthesis after function $name");
        double arg = _parseExpression();
        if (!_eat(41)) throw FormatException("Missing closing parenthesis after function $name");
        
        if (name == 'sin') {
          x = math.sin(arg * math.pi / 180.0);
        } else if (name == 'cos') {
          x = math.cos(arg * math.pi / 180.0);
        } else if (name == 'tan') {
          x = math.tan(arg * math.pi / 180.0);
        } else if (name == 'asin') {
          if (arg < -1 || arg > 1) throw ArgumentError("asin domain is [-1, 1]");
          x = math.asin(arg) * 180.0 / math.pi;
        } else if (name == 'acos') {
          if (arg < -1 || arg > 1) throw ArgumentError("acos domain is [-1, 1]");
          x = math.acos(arg) * 180.0 / math.pi;
        } else if (name == 'atan') {
          x = math.atan(arg) * 180.0 / math.pi;
        } else if (name == 'sqrt' || name == '√') {
          if (arg < 0) throw ArgumentError("Square root of negative number");
          x = math.sqrt(arg);
        } else if (name == 'log') {
          if (arg <= 0) throw ArgumentError("Logarithm of non-positive number");
          x = math.log(arg) / math.ln10;
        } else if (name == 'ln') {
          if (arg <= 0) throw ArgumentError("Logarithm of non-positive number");
          x = math.log(arg);
        } else if (name == 'abs') {
          x = arg.abs();
        } else {
          throw FormatException("Unknown function: $name");
        }
      }
    } else {
      throw FormatException("Unexpected character: ${String.fromCharCode(_ch)}");
    }

    // Postfix operators loop
    for (;;) {
      if (_eat(33)) { // '!'
        x = _factorial(x);
      } else if (_eat(37)) { // '%'
        x = x / 100.0;
      } else if (_eat(94)) { // '^'
        x = math.pow(x, _parseFactor()).toDouble();
      } else {
        break;
      }
    }

    return x;
  }

  double _factorial(double val) {
    if (val < 0 || val != val.toInt()) {
      throw ArgumentError("Factorial of non-negative integer only");
    }
    int n = val.toInt();
    if (n > 170) throw ArgumentError("Factorial overflow");
    double result = 1;
    for (int i = 2; i <= n; i++) {
      result *= i;
    }
    return result;
  }
}
