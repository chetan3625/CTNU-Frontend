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
  bool _isShiftActive = false;

  // List of standard scientific/physical constants for Engineering & Pharmacy
  final List<Map<String, String>> _constants = [
    {
      'symbol': 'Na',
      'name': 'Avogadro\'s Number',
      'value': '6.02214076e23',
      'unit': 'mol⁻¹',
      'desc': 'Pharmacy: Gas laws, molecular calculations'
    },
    {
      'symbol': 'h',
      'name': 'Planck Constant',
      'value': '6.62607015e-34',
      'unit': 'J·s',
      'desc': 'Engineering: Quantum mechanics, photon energy'
    },
    {
      'symbol': 'R',
      'name': 'Universal Gas Constant',
      'value': '8.314462618',
      'unit': 'J/(mol·K)',
      'desc': 'Pharmacy & Eng: Ideal gas equations, thermodynamics'
    },
    {
      'symbol': 'F',
      'name': 'Faraday Constant',
      'value': '96485.3321',
      'unit': 'C/mol',
      'desc': 'Pharmacy & Eng: Electrochemistry, electrolysis'
    },
    {
      'symbol': 'c',
      'name': 'Speed of Light',
      'value': '299792458',
      'unit': 'm/s',
      'desc': 'Engineering: Relativistic physics, electromagnetism'
    },
    {
      'symbol': 'g',
      'name': 'Standard Gravity',
      'value': '9.80665',
      'unit': 'm/s²',
      'desc': 'Engineering: Dynamics, load calculations'
    },
    {
      'symbol': 'k',
      'name': 'Boltzmann Constant',
      'value': '1.380649e-23',
      'unit': 'J/K',
      'desc': 'Engineering: Statistical mechanics, gas kinetics'
    },
    {
      'symbol': 'e',
      'name': 'Elementary Charge',
      'value': '1.602176634e-19',
      'unit': 'C',
      'desc': 'Engineering: Charge of single electron/proton'
    },
    {
      'symbol': 'G',
      'name': 'Gravitational Constant',
      'value': '6.6743e-11',
      'unit': 'm³/(kg·s²)',
      'desc': 'Engineering: Orbital mechanics, gravity models'
    },
    {
      'symbol': 'me',
      'name': 'Electron Mass',
      'value': '9.1093837e-31',
      'unit': 'kg',
      'desc': 'Engineering: Semiconductor physics'
    },
    {
      'symbol': 'mp',
      'name': 'Proton Mass',
      'value': '1.67262192e-27',
      'unit': 'kg',
      'desc': 'Engineering: Nuclear physics, mass specs'
    },
    {
      'symbol': 'u',
      'name': 'Atomic Mass Unit',
      'value': '1.66053906e-27',
      'unit': 'kg',
      'desc': 'Pharmacy: Atomic weight calculations'
    },
  ];

  void _onKeyPress(String value) {
    setState(() {
      _showError = false;
      if (value == 'C') {
        _expression = '';
        _result = '';
      } else if (value == '⌫') {
        if (_expression.isNotEmpty) {
          // Deleting multi-character functions cleanly
          if (_expression.endsWith('sinh(') ||
              _expression.endsWith('cosh(') ||
              _expression.endsWith('tanh(') ||
              _expression.endsWith('asin(') ||
              _expression.endsWith('acos(') ||
              _expression.endsWith('atan(') ||
              _expression.endsWith('cbrt(') ||
              _expression.endsWith('sqrt(')) {
            _expression = _expression.substring(0, _expression.length - 5);
          } else if (_expression.endsWith('sin(') ||
              _expression.endsWith('cos(') ||
              _expression.endsWith('tan(') ||
              _expression.endsWith('log(') ||
              _expression.endsWith('abs(')) {
            _expression = _expression.substring(0, _expression.length - 4);
          } else if (_expression.endsWith('ln(') || _expression.endsWith('10^(')) {
            _expression = _expression.substring(0, _expression.length - 3);
          } else if (_expression.endsWith('e^(')) {
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
      } else if (value == 'SHIFT') {
        _isShiftActive = !_isShiftActive;
      } else if (value == 'CONST') {
        _showConstantsPanel();
      } else {
        _expression += value;
        _isShiftActive = false; // Reset shift after keypress
      }
    });
  }

  void _showConstantsPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141419),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Scientific & Pharmacy Constants',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _constants.length,
                itemBuilder: (context, index) {
                  final c = _constants[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: Colors.deepPurple.shade900,
                      child: Text(
                        c['symbol']!,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(c['name']!, style: const TextStyle(color: Colors.white)),
                    subtitle: Text('${c['value']} ${c['unit']}\n${c['desc']}', 
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    isThreeLine: true,
                    trailing: const Icon(Icons.arrow_downward, color: Colors.green),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _expression += c['value']!;
                      });
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
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
          .replaceAll('π', 'pi')
          .replaceAll('ˣ√', 'rt');

      // Auto-close missing parentheses
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
            // Shift indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
              alignment: Alignment.centerLeft,
              height: 24,
              child: _isShiftActive
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade800,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'SHIFT',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // Calculator Display Area
            Expanded(
              flex: isLandscape ? 2 : 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
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
                          fontSize: 30,
                          fontWeight: FontWeight.w300,
                          color: Colors.white70,
                          letterSpacing: 1.0,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _result,
                        style: TextStyle(
                          fontSize: 42,
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
              flex: isLandscape ? 6 : 9,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                color: const Color(0xFF141419),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildButtonRow(['SHIFT', 'CONST', '(', ')', '÷']),
                    _buildButtonRow(['sin(', 'cos(', 'tan(', '^', '×']),
                    _buildButtonRow(['√(', 'log(', 'ln(', '!', '-']),
                    _buildButtonRow(['7', '8', '9', 'π', '+']),
                    _buildButtonRow(['4', '5', '6', 'e', 'C']),
                    _buildButtonRow(['1', '2', '3', '⌫', '=']),
                    _buildButtonRow(['0', '.', 'abs(', '^-1', '00']),
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
              padding: const EdgeInsets.all(2.5),
              child: _buildCalculatorButton(key),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCalculatorButton(String text) {
    final theme = Theme.of(context);
    
    // Resolve key behavior based on SHIFT state
    String activeKey = text;
    if (_isShiftActive) {
      if (text == 'C') activeKey = 'abs(';
      if (text == '⌫') activeKey = '^-1';
      if (text == '(') activeKey = 'sinh(';
      if (text == ')') activeKey = 'cosh(';
      if (text == '÷') activeKey = 'tanh(';
      if (text == 'sin(') activeKey = 'asin(';
      if (text == 'cos(') activeKey = 'acos(';
      if (text == 'tan(') activeKey = 'atan(';
      if (text == '^') activeKey = 'ˣ√';
      if (text == '√(') activeKey = 'cbrt(';
      if (text == 'log(') activeKey = '10^(';
      if (text == 'ln(') activeKey = 'e^(';
      if (text == '!') activeKey = 'P';
      if (text == 'π') activeKey = 'C';
      if (text == 'e') activeKey = '%';
    }

    bool isShift = text == 'SHIFT';
    bool isConst = text == 'CONST';
    bool isOperator = ['÷', '×', '-', '+', '='].contains(activeKey) || text == '÷' || text == '×' || text == '-' || text == '+';
    bool isFunction = ['sin(', 'cos(', 'tan(', 'asin(', 'acos(', 'atan(', 'sinh(', 'cosh(', 'tanh(', 'log(', 'ln(', '√(', 'cbrt(', '^', '(', ')', '!', 'abs(', '^-1', '10^(', 'e^(', 'P', 'C', '%', 'ˣ√'].contains(activeKey);
    bool isClear = ['C', '⌫'].contains(text);

    Color buttonColor;
    Color textColor = Colors.white;

    if (isShift) {
      buttonColor = _isShiftActive ? Colors.amber.shade800 : const Color(0xFF33333C);
      textColor = _isShiftActive ? Colors.black : Colors.amber;
    } else if (isConst) {
      buttonColor = const Color(0xFF282835);
      textColor = theme.colorScheme.secondary;
    } else if (isOperator) {
      buttonColor = activeKey == '=' ? theme.colorScheme.secondary : theme.colorScheme.primary;
      textColor = activeKey == '=' ? Colors.black : Colors.white;
    } else if (isClear) {
      buttonColor = const Color(0xFF2C2C35);
      textColor = const Color(0xFFFF8A80);
    } else if (isFunction) {
      buttonColor = const Color(0xFF1E1E24);
      textColor = theme.colorScheme.secondary;
    } else {
      buttonColor = const Color(0xFF24242C);
    }

    // Dynamic Label Formatting
    String displayLabel = text;
    if (_isShiftActive) {
      if (text == 'C') displayLabel = 'abs';
      if (text == '⌫') displayLabel = 'x⁻¹';
      if (text == '(') displayLabel = 'sinh';
      if (text == ')') displayLabel = 'cosh';
      if (text == '÷') displayLabel = 'tanh';
      if (text == 'sin(') displayLabel = 'sin⁻¹';
      if (text == 'cos(') displayLabel = 'cos⁻¹';
      if (text == 'tan(') displayLabel = 'tan⁻¹';
      if (text == '^') displayLabel = 'ˣ√';
      if (text == '√(') displayLabel = '³√';
      if (text == 'log(') displayLabel = '10ˣ';
      if (text == 'ln(') displayLabel = 'eˣ';
      if (text == '!') displayLabel = 'nPr';
      if (text == 'π') displayLabel = 'nCr';
      if (text == 'e') displayLabel = '%';
    } else {
      if (text == 'sin(') displayLabel = 'sin';
      if (text == 'cos(') displayLabel = 'cos';
      if (text == 'tan(') displayLabel = 'tan';
      if (text == 'log(') displayLabel = 'log';
      if (text == 'ln(') displayLabel = 'ln';
      if (text == '√(') displayLabel = '√';
      if (text == 'abs(') displayLabel = 'abs';
      if (text == '!') displayLabel = 'x!';
      if (text == '^-1') displayLabel = 'x⁻¹';
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        foregroundColor: textColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: EdgeInsets.zero,
      ),
      onPressed: () => _onKeyPress(activeKey),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          displayLabel,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Recursive Descent Math Parser with Scientific E-notation & Postfix operators
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
      } else if (_eat(80)) { // 'P' (permutation)
        double r = _parseFactor();
        x = _permutation(x, r);
      } else if (_eat(67)) { // 'C' (combination)
        double r = _parseFactor();
        x = _combination(x, r);
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
      // Support E-notation (scientific notation like 6.022e23, 1.6e-19)
      if (_ch == 101 || _ch == 69) { // 'e' or 'E'
        int peekPos = _pos + 1;
        if (peekPos < expression.length) {
          int nextCh = expression.codeUnitAt(peekPos);
          if ((nextCh >= 48 && nextCh <= 57) || nextCh == 43 || nextCh == 45) {
            _nextChar(); // consume 'e'
            if (_ch == 43 || _ch == 45) {
              _nextChar(); // consume '+' or '-'
            }
            while (_ch >= 48 && _ch <= 57) {
              _nextChar();
            }
          }
        }
      }
      x = double.parse(expression.substring(startPos, _pos));
    } else if ((_ch >= 97 && _ch <= 122) || _ch == 960 || _ch == 8730) { // functions, constants
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
        } else if (name == 'sinh') {
          x = (math.exp(arg) - math.exp(-arg)) / 2.0;
        } else if (name == 'cosh') {
          x = (math.exp(arg) + math.exp(-arg)) / 2.0;
        } else if (name == 'tanh') {
          double ep = math.exp(arg);
          double em = math.exp(-arg);
          x = (ep - em) / (ep + em);
        } else if (name == 'asinh') {
          x = math.log(arg + math.sqrt(arg * arg + 1));
        } else if (name == 'acosh') {
          if (arg < 1) throw ArgumentError("acosh domain is [1, inf]");
          x = math.log(arg + math.sqrt(arg * arg - 1));
        } else if (name == 'atanh') {
          if (arg <= -1 || arg >= 1) throw ArgumentError("atanh domain is (-1, 1)");
          x = 0.5 * math.log((1.0 + arg) / (1.0 - arg));
        } else if (name == 'sqrt' || name == '√') {
          if (arg < 0) throw ArgumentError("Square root of negative number");
          x = math.sqrt(arg);
        } else if (name == 'cbrt') {
          x = arg < 0 ? -math.pow(-arg, 1.0 / 3.0).toDouble() : math.pow(arg, 1.0 / 3.0).toDouble();
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
      } else if (_eat(114)) { // 'r' - check if it's 'rt' (x-th root of y, e.g. 3 rt 8 = 2)
        if (_eat(116)) {
          double base = _parseFactor();
          x = math.pow(base, 1.0 / x).toDouble();
        } else {
          _pos--;
          _ch = 114;
          break;
        }
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

  double _permutation(double nVal, double rVal) {
    if (nVal < 0 || rVal < 0 || nVal != nVal.toInt() || rVal != rVal.toInt() || rVal > nVal) {
      throw ArgumentError("nPr requires non-negative integers where n >= r");
    }
    int n = nVal.toInt();
    int r = rVal.toInt();
    double result = 1;
    for (int i = n - r + 1; i <= n; i++) {
      result *= i;
    }
    return result;
  }

  double _combination(double nVal, double rVal) {
    if (nVal < 0 || rVal < 0 || nVal != nVal.toInt() || rVal != rVal.toInt() || rVal > nVal) {
      throw ArgumentError("nCr requires non-negative integers where n >= r");
    }
    int n = nVal.toInt();
    int r = rVal.toInt();
    if (r > n - r) r = n - r;
    double result = 1;
    for (int i = 1; i <= r; i++) {
      result *= (n - r + i) / i;
    }
    return result;
  }
}
