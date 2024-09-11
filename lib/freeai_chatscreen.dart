import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:language_code/language_code.dart';

class FreeAIChatScreen extends StatefulWidget {
  const FreeAIChatScreen({super.key});

  @override
  State<FreeAIChatScreen> createState() => _FreeAIChatScreenState();
}

class _FreeAIChatScreenState extends State<FreeAIChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ImagePicker _picker = ImagePicker();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  Uint8List? _selectedImageBytes;
  String? _apiKey;
  String? _language; // Default language
  String? _languageEnglish;
  final _defaultPrompt = "You are ai chatbot. Please translate all the result in <language>.";
  String? _customPrompt = '';
  GenerativeModel? _model;

  @override
  void initState() {
    super.initState();
    _loadSettings(); // Detect system language and set as default
  }

  void _genModel() {
    if (_apiKey != null && _languageEnglish != null) {
      _model = GenerativeModel(
          model: "gemini-1.5-flash",
          apiKey: _apiKey!,
          systemInstruction: Content.system(
              _customPrompt!.replaceAll('<language>', _languageEnglish!))
      );
    }
  }
  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _language = prefs.getString('language');
      if (_language == null) {
        _language = LanguageCode.locale.toString();
        prefs.setString('language', _language!);
      }
      _languageEnglish = LanguageCodes.fromCode(_language!).englishName;

      _customPrompt = prefs.getString('custom_prompt');
      if (_customPrompt == null) {
        _customPrompt = _defaultPrompt;
        prefs.setString('custom_prompt', _customPrompt!);
      }

      _apiKey = prefs.getString('api_key');
      if (_apiKey == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showApiKeyDialog();
        });
      } else {
        _genModel();
      }
    });
  }

  Future<void> _saveLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', language);
    setState(() {
      _language = language;
      _languageEnglish = LanguageCodes.fromCode(_language!).englishName;
    });
  }

  Future<void> _saveCustomPrompt(String prompt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_prompt', prompt);
    setState(() {
      _customPrompt = prompt;
    });
  }

  Future<void> _saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_key', apiKey);
    setState(() {
      _apiKey = apiKey;
      _genModel();
    });
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String tempApiKey = _apiKey ?? '';
        String selectedLanguage = _language!;
        String tempCustomPrompt = _customPrompt!;
        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width,
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Settings',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: TextEditingController(text: tempApiKey),
                    onChanged: (value) {
                      tempApiKey = value;
                    },
                    decoration: const InputDecoration(
                      labelText: 'API Key',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedLanguage,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Select Language',
                      border: OutlineInputBorder(),
                    ),
                    items: LanguageCodes.values.map((value) {
                      return DropdownMenuItem<String>(
                        value: value.locale.toString(),
                        child: Text(value.nativeName, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedLanguage = newValue!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: TextEditingController(text: tempCustomPrompt),
                    onChanged: (value) {
                      tempCustomPrompt = value;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Custom Prompt',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 5,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        child: const Text('Cancel'),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        child: const Text('Save'),
                        onPressed: () async {
                          List<Future> futures = [];
                          if (tempApiKey.isNotEmpty) {
                            futures.add(_saveApiKey(tempApiKey));
                          }
                          futures.add(_saveLanguage(selectedLanguage));
                          if (tempCustomPrompt.isNotEmpty) {
                            futures.add(_saveCustomPrompt(tempCustomPrompt));
                          }
                          await Future.wait(futures);
                          _genModel();
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showApiKeyDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        String tempApiKey = '';
        return AlertDialog(
          title: const Text('Enter API Key'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                onChanged: (value) {
                  tempApiKey = value;
                },
                decoration: const InputDecoration(
                  hintText: 'Enter your API key here',
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                child: const Text('Get API Key'),
                onPressed: () {
                  _launchApiKeyUrl();
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                if (tempApiKey.isNotEmpty) {
                  _saveApiKey(tempApiKey);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _launchApiKeyUrl() async {
    final url = Uri.parse('https://makersuite.google.com/app/apikey');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  KeyEventResult _onKeyPress(KeyEvent event) {
    if (!HardwareKeyboard.instance.isShiftPressed &&
        event.logicalKey.keyLabel == 'Enter') {
      if (event is KeyDownEvent) {
        _handleSubmitted(_textController.text.trim());
      }

      return KeyEventResult.handled;
    } else {
      return KeyEventResult.ignored;
    }
  }

  void _handleSubmitted(String text) async {
    if (text.isEmpty && _selectedImageBytes == null) return;
    if (_apiKey == null) {
      _showApiKeyDialog();
      return;
    }

    ChatMessage message = ChatMessage(
      text: text,
      isUser: true,
      imageBytes: _selectedImageBytes,
    );
    setState(() {
      _messages.insert(0, message);
    });
    _textController.clear();

    // final content = [Content.text("$text.\n${_defaultPrompt.replaceAll("<language>", _languageEnglish)}")];
    final content = [Content.text(text)];
    if (_selectedImageBytes != null) content.add(Content.data("image/png", _selectedImageBytes!));
    _selectedImageBytes = null; // Clear the selected image after sending
    try {
      final response = await _model!.generateContent(content);
      ChatMessage botMessage = ChatMessage(
        text: response.text.toString(),
        isUser: false,
      );
      setState(() {
        _messages.insert(0, botMessage);
      });
    } catch (e) {
      print("Error generating content: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }

    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      print("Error picking image: $e");
    } finally {
      _focusNode.requestFocus();
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        print("File picked: ${result.files.single.name}");
        // Handle file picking here
      }
    } catch (e) {
      print("Error picking file: $e");
    } finally {
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Free AI Chat"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8.0),
                reverse: true,
                itemBuilder: (context, index) {
                  if (index < _messages.length) {
                    return _messages[index];
                  }
                  return null;
                },
                itemCount: _messages.length,
              ),
            ),
            Container(
              decoration: BoxDecoration(color: Theme.of(context).cardColor),
              child: _buildTextComposer(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextComposer() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10),
      child: Row(
        children: <Widget>[
          if (_textController.text.isEmpty)
            ...[
              IconButton(
                icon: const Icon(Icons.camera_alt),
                onPressed: () => _pickImage(ImageSource.camera),
              ),
              IconButton(
                icon: const Icon(Icons.photo),
                onPressed: () => _pickImage(ImageSource.gallery),
              ),
              IconButton(
                icon: const Icon(Icons.attach_file),
                onPressed: _pickFile,
              ),
            ]
          else
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                setState(() {
                  _textController.clear();
                });
              },
            ),
          Flexible(
            fit: FlexFit.tight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedImageBytes != null)
                  Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 8.0),
                        height: 100,
                        width: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4.0),
                          image: DecorationImage(
                            image: MemoryImage(_selectedImageBytes!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 18),
                        onPressed: () => setState(() => _selectedImageBytes = null),
                      ),
                    ],
                  ),
                Container(
                  margin: const EdgeInsets.only(top: 5.0),
                  child: Scrollbar(
                    child: Focus(
                      onKeyEvent: (FocusNode node, KeyEvent event) {
                        return _onKeyPress(event);
                      },
                      child: TextField(
                        autofocus: true,
                        focusNode: _focusNode,
                        controller: _textController,
                        onSubmitted: _handleSubmitted,
                        onChanged: (text) {
                          setState(() {}); // Trigger rebuild when text changes
                        },
                        decoration: const InputDecoration.collapsed(hintText: "Send a message"),
                        maxLines: 4,
                        minLines: 1,
                        keyboardType: TextInputType.multiline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () => _handleSubmitted(_textController.text),
          ),
        ],
      ),
    );
  }
}

class ChatMessage extends StatelessWidget {
  const ChatMessage({super.key, required this.text, required this.isUser, this.imageBytes});

  final String text;
  final bool isUser;
  final Uint8List? imageBytes;

  void _showFullImage(BuildContext context) {
    if (imageBytes != null) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            insetPadding: EdgeInsets.zero, // Remove default padding
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black,
                child: InteractiveViewer(
                  panEnabled: true,
                  boundaryMargin: const EdgeInsets.all(20),
                  minScale: 0.5,
                  maxScale: 4,
                  child: Image.memory(
                    imageBytes!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (!isUser)
            Container(
              margin: const EdgeInsets.only(right: 16.0),
              child: const CircleAvatar(child: Image(image: AssetImage("assets/gemini.png"))),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: <Widget>[
                if (imageBytes != null)
                  GestureDetector(
                    onTap: () => _showFullImage(context),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      height: 150,
                      width: 200,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Image.memory(imageBytes!, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                if (text.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue : Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: MarkdownBody(
                      data: text,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(color: isUser ? Colors.white : Colors.black),
                        code: TextStyle(
                          backgroundColor: isUser ? Colors.blue[400] : Colors.grey[300],
                          color: isUser ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isUser)
            Container(
              margin: const EdgeInsets.only(left: 16.0),
              child: const CircleAvatar(child: Text("You")),
            ),
        ],
      ),
    );
  }
}