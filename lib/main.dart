// lib/main.dart
// Hybreak ST25 NFC Reader & Writer
// Enhanced UI: Show record count on read

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:ndef/ndef.dart';

void main() => runApp(const St25NdefTool());

class St25NdefTool extends StatelessWidget {
  const St25NdefTool({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hybreak ST25 NFC',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(120, 45),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        ),
      ),
      home: const NfcPage(),
    );
  }
}

class NfcPage extends StatefulWidget {
  const NfcPage({super.key});
  @override
  State<NfcPage> createState() => _NfcPageState();
}

class _NfcPageState extends State<NfcPage> {
  final _minPresCtl    = TextEditingController();
  final _maxPresCtl    = TextEditingController();
  final _maxDiffCtl    = TextEditingController();
  final _minLocPresCtl = TextEditingController();
  final _locDurCtl     = TextEditingController();

  String _status = 'Idle';
  String _output = '';
  bool   _busy   = false;

  @override
  void dispose() {
    _minPresCtl.dispose();
    _maxPresCtl.dispose();
    _maxDiffCtl.dispose();
    _minLocPresCtl.dispose();
    _locDurCtl.dispose();
    super.dispose();
  }

  /// Reads NDEF records and shows how many were found.
  Future<void> _readNdef() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = 'Reading tag...';
      _output = '';
    });
    try {
      await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 20),
        iosAlertMessage: 'Hold your ST25 tag near phone',
      );
      final recs = await FlutterNfcKit.readNDEFRecords();
      // Update status with record count
      setState(() {
        _status = 'Read successful: ${recs.length} record${recs.length == 1 ? '' : 's'} found';
      });

      final buf = StringBuffer();
      for (var i = 0; i < recs.length; i++) {
        final r = recs[i];
        buf.writeln('• Record ${i+1}');
        if (r is TextRecord) buf.writeln('  Text: ${r.text}');
        else if (r is UriRecord) buf.writeln('  URI: ${r.uriString}');
        else buf.writeln('  Raw: ${base64.encode(r.payload as List<int>)}');
        buf.writeln();
      }
      setState(() {
        _output = buf.toString();
      });

      await FlutterNfcKit.finish(iosAlertMessage: 'Done reading');
    } catch (e) {
      await FlutterNfcKit.finish(iosErrorMessage: 'Read error');
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  /// Writes config parameters to the tag as a single TextRecord.
  Future<void> _writeConfig() async {
    if (_busy) return;
    final minP = _minPresCtl.text;
    final maxP = _maxPresCtl.text;
    final diff = _maxDiffCtl.text;
    final minL = _minLocPresCtl.text;
    final dur  = _locDurCtl.text;
    final txt = 'minpres=$minP,maxpres=$maxP,maxdiff=$diff,minlocpres=$minL,locdur=$dur';

    setState(() {
      _busy = true;
      _status = 'Writing tag...';
      _output = '';
    });
    try {
      final tag = await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 20),
        iosAlertMessage: 'Hold your ST25 tag near phone',
      );
      if (tag.ndefWritable != true) {
        setState(() => _status = 'Tag not writable');
        await FlutterNfcKit.finish();
        return;
      }
      final rec = TextRecord(
        encoding: TextEncoding.UTF8,
        language: 'en',
        text: txt,
      );
      await FlutterNfcKit.writeNDEFRecords([rec]);
      await FlutterNfcKit.finish(iosAlertMessage: 'Write done');
      setState(() => _status = 'Write successful');
    } catch (e) {
      await FlutterNfcKit.finish(iosErrorMessage: 'Write error');
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Widget _buildField(String label, TextEditingController ctl) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: TextField(
          controller: ctl,
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: Colors.indigo.shade50,
          ),
          keyboardType: TextInputType.number,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/Bohr Limit.png', height: 32),
            const SizedBox(width: 12),
            const Text('Hybreak NFC', style: TextStyle(fontSize: 20)),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(children: [
                      _buildField('Min Pressure', _minPresCtl),
                      _buildField('Max Pressure', _maxPresCtl),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      _buildField('Max Diff', _maxDiffCtl),
                      _buildField('Min Lock Pres', _minLocPresCtl),
                      _buildField('Lock Dur', _locDurCtl),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _busy ? null : _readNdef,
                  icon: const Icon(Icons.nfc),
                  label: const Text('Read'),
                ),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _writeConfig,
                  icon: const Icon(Icons.save),
                  label: const Text('Write'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Status: $_status', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _output.isEmpty ? 'No data yet.' : _output,
                    style: const TextStyle(fontFamily: 'Courier'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
