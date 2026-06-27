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
          // If deleting a function like sin(, cos(, tan(, log(, ln(
          if (_expression.endsWith('sin(') ||
              _expression.endsWith('cos(') ||
              _expression.endsWith('tan(') ||
              _expression.endsWith('log(')) {
            _expression = _expression.substring(0, _expression.length - 4);
          } else if (_expression.endsWith('ln(')) {
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

      final evaluator = MathEvaluator(parsedExpr);
      final evalResult = evaluator.parse();
      
      setState(() {
        // Format double results to avoid long floating point representations
        if (evalResult.isInfinite || evalResult.isNaN) {
          _result = 'Error';
          _showError = true;
        } else {
          if (evalResult == evalResult.toInt()) {
            _result = evalResult.toInt().toString();
          } else {
            _result = evalResult.toStringAsFixed(6);
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
      backgroundColor: const Color(0xFF101010),
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
                          fontSize: 36,
                          fontWeight: FontWeight.w300,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _result,
                        style: TextStyle(
                          fontSize: 48,
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
            const Divider(color: Color(0xFF222222), height: 1),

            // Calculator Keypad
            Expanded(
              flex: isLandscape ? 5 : 7,
              child: Container(
                padding: const EdgeInsets.all(8.0),
                color: const Color(0xFF151515),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildButtonRow(['C', '(', ')', '⌫', '÷']),
                    _buildButtonRow(['sin(', 'cos(', 'tan(', '^', '×']),
                    _buildButtonRow(['7', '8', '9', 'log(', '-']),
                    _buildButtonRow(['4', '5', '6', 'ln(', '+']),
                    _buildButtonRow(['1', '2', '3', '√(', '=']),
                    _buildButtonRow(['0', '.', 'π', 'e']),
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
              padding: const EdgeInsets.all(4.0),
              child: _buildCalculatorButton(key),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCalculatorButton(String text) {
    final theme = Theme.of(context);
    
    // Styling attributes based on key types
    bool isOperator = ['÷', '×', '-', '+', '='].contains(text);
    bool isFunction = ['sin(', 'cos(', 'tan(', 'log(', 'ln(', '√(', '^', '(', ')'].contains(text);
    bool isClear = ['C', '⌫'].contains(text);

    Color buttonColor;
    Color textColor = Colors.white;

    if (isOperator) {
      buttonColor = text == '=' ? theme.colorScheme.secondary : theme.colorScheme.primary;
      textColor = text == '=' ? Colors.black : Colors.white;
    } else if (isClear) {
      buttonColor = const Color(0xFF333333);
      textColor = Colors.amber;
    } else if (isFunction) {
      buttonColor = const Color(0xFF252525);
      textColor = theme.colorScheme.secondary;
    } else {
      buttonColor = const Color(0xFF1E1E1E);
    }

    // Display labels cleanups
    String displayLabel = text;
    if (text == 'sin(') displayLabel = 'sin';
    if (text == 'cos(') displayLabel = 'cos';
    if (text == 'tan(') displayLabel = 'tan';
    if (text == 'log(') displayLabel = 'log';
    if (text == 'ln(') displayLabel = 'ln';
    if (text == '√(') displayLabel = '√';

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        foregroundColor: textColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: EdgeInsets.zero,
      ),
      onPressed: () => _onKeyPress(text),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          displayLabel,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Recursive Descent Math Parser for Scientific Calculations
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
        } else if (name == 'sqrt' || name == '√') {
          x = math.sqrt(arg);
        } else if (name == 'log') {
          x = math.log(arg) / math.ln10;
        } else if (name == 'ln') {
          x = math.log(arg);
        } else {
          throw FormatException("Unknown function: $name");
        }
      }
    } else {
      throw FormatException("Unexpected character: ${String.fromCharCode(_ch)}");
    }

    if (_eat(94)) {
      x = math.pow(x, _parseFactor()).toDouble(); // ^
    }

    return x;
  }
}
