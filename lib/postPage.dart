import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;


class Postpage extends StatefulWidget {
  const Postpage({super.key});

  @override
  State<Postpage> createState() => _PostpageState();
}

class _PostpageState extends State<Postpage> {
  final TextEditingController _textController = TextEditingController();
  bool _isLoading = false;
  List<dynamic> _factChecks = [];
  String? _errorMessage;
  final _supabase = Supabase.instance.client;
  String _riskLevel = 'Medium';
  XFile? _selectedMedia;
  final ImagePicker _picker = ImagePicker();

 String apiKey = dotenv.env['FACT_CHECK_API_KEY'] ?? '';
String geminiApiKey =  dotenv.env['GOOGLE_API_KEY'] ?? '';

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

Map<String, dynamic> _formatGeminiResponseAsFactCheck(String claimText, String response) {
  // Extract textual rating from the Gemini response
  //final riskMatch = RegExp(r'Risk:\s*(Low|Medium|High)', caseSensitive: false).firstMatch(response);
  final evidenceMatch = RegExp(
    r'\*\*Evidence Summary\*\*:\s*(.*?)\n\s*\n',  // captures until the next double line break or bullet section
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(response);

  final evidenceSummary = evidenceMatch != null
      ? evidenceMatch.group(1)?.trim()
      : 'No evidence summary found.';
      
  return {
    'text': claimText,
    'claimReview': [
      {
        'publisher': {
          'name': 'Gemini AI',
          'site': 'https://ai.google.com/gemini/',
        },
        'textualRating': evidenceSummary,
        'title': 'AI-generated Fact Check',
        'url': '',
        'reviewDate': DateTime.now().toIso8601String(),
        'languageCode': 'en',
        'reviewBody': response,
      }
    ]
  };
}



Future<void> _searchByText(String query) async {
  if (query.isEmpty) return;

  setState(() {
    _isLoading = true;
    _factChecks = [];
    _errorMessage = null;
  });

  try {
    final url = Uri.parse(
      'https://factchecktools.googleapis.com/v1alpha1/claims:search?query=${Uri.encodeComponent(query)}&key=$apiKey',
    );

    final response = await http.get(url);

    if (response.statusCode != 200) throw Exception('Failed to fetch fact checks: ${response.statusCode}');

    final data = json.decode(response.body);
    final claims = data['claims'] ?? [];

    if (claims.isEmpty) {
      // No fact check found — fallback to Gemini
      final geminiResponse = await _queryGeminiAI(query);
      final geminiFact = _formatGeminiResponseAsFactCheck(query, geminiResponse);
      debugPrint("@@@@@$geminiFact");

      setState(() {
        _factChecks = [geminiFact];
        _riskLevel = 'Unknown'; // or analyze content further
        //_errorMessage = 'No official fact checks found. Showing Gemini’s response.';
      });
    } else {
      final firstRating = claims[0]['claimReview']?[0]['textualRating']?.toString().toLowerCase() ?? '';
      String riskLevel = 'Low';
      if (firstRating.contains('false')) {
        riskLevel = 'High';
      } else if (firstRating.contains('misleading')) {
        riskLevel = 'Medium';
      }

      setState(() {
        _factChecks = claims;
        _riskLevel = riskLevel;
        _errorMessage = null;
      });
    }
  } catch (e) {
    // API error — fallback to Gemini
    final geminiResponse = await _queryGeminiAI(query);
    final geminiFact = _formatGeminiResponseAsFactCheck(query, geminiResponse);

    setState(() {
      _factChecks = [geminiFact];
      _riskLevel = 'Unknown';
      _errorMessage = 'Fact Check API failed. Showing Gemini’s response.';
    });
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

Future<String> _queryGeminiAI(String prompt) async {
 // final geminiApiKey = 'YOUR_GEMINI_API_KEY';
  final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$geminiApiKey');

  final body = json.encode({
  "contents": [
    {
      "parts": [
        {
          "text": """
Please fact-check the following claim and return a structured response with these fields:

- **Risk**: (Low/Medium/High)
- **Evidence Summary**: A concise summary of the factual basis
- **Key Claims**: Bullet points of relevant claims
- **Sources**: List of sources used, if available

Claim: "$prompt"
"""
          }
        ]
    }
      ]
    }
  );

  try {
    final response = await http.post(
      uri,
      headers: {
        "Content-Type": "application/json",
        "X-goog-api-key": geminiApiKey,
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final generatedText = data['candidates'][0]['content']['parts'][0]['text'];
      return generatedText ?? 'No response from Gemini.';
    } else {
      return 'Gemini API error: ${response.statusCode}';
    }
  } catch (e) {
    return 'Failed to query Gemini: $e';
  }
}

Future<void> _searchByImage(XFile imageFile) async {
  setState(() {
    _isLoading = true;
    _factChecks = [];
    _errorMessage = null;
  });

  try {
    // 1. First, try the Fact Check Tools API with a description from Gemini?
    // This is tricky because the Fact Check API is text-based.
    // We can skip this step and go straight to Gemini for images.
    // For a more advanced integration, you could use Gemini to describe the image
    // and then use THAT description in the Fact Check API.

    // Since direct image fact-checking APIs are rare, we primarily rely on Gemini.
    final geminiResponse = await _queryGeminiAIVision(imageFile);
    final geminiFact = _formatGeminiResponseAsFactCheck("Image Analysis", geminiResponse);
    debugPrint("@@@@@ Image Analysis: $geminiFact");

    setState(() {
      _factChecks = [geminiFact];
      _riskLevel = 'Unknown'; // You can parse this from the response
      //_errorMessage = 'No official fact checks found for images. Showing Gemini’s analysis.';
    });

  } catch (e) {
    // Error handling
    setState(() {
      _errorMessage = 'Failed to analyze image: $e';
    });
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

Future<String> _queryGeminiAIVision(XFile imageFile) async {
  // Read the image file as bytes and convert to base64
  final bytes = await imageFile.readAsBytes();
  final base64Image = base64Encode(bytes);

  // Determine the MIME type (simplified, assumes jpeg)
  // For a more robust solution, you could check the file extension
  final mimeType = 'image/jpeg';

  final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$geminiApiKey');

  // Construct the request body with the image and a detailed prompt
  final body = json.encode({
  "contents": [
    {
      "parts": [
        {
          "text": """
Please analyze this image and perform a fact-checking assessment. Look for signs of manipulation (AI generation, photoshopping), misleading context, or known misinformation tropes.

Return a structured response with these fields:

- **Risk**: (Low/Medium/High) - Based on potential for misinformation.
- **Evidence Summary**: A concise summary of what you see and its authenticity cues.
- **Key Claims**: Bullet points of relevant details, inconsistencies, or identifiers.
- **Sources**: If you recognize a famous scene, person, or known meme, list it.
"""
        },
        {
          "inline_data": {
            "mime_type": mimeType,
            "data": base64Image
          }
        }
      ]
    }
  ]
});

  try {
    final response = await http.post(
      uri,
      headers: {
        "Content-Type": "application/json",
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final generatedText = data['candidates'][0]['content']['parts'][0]['text'];
      return generatedText ?? 'No response from Gemini.';
    } else {
      // Handle API errors specifically
      final errorData = json.decode(response.body);
      return 'Gemini API error (${response.statusCode}): ${errorData['error']['message'] ?? 'Unknown error'}';
    }
  } catch (e) {
    return 'Failed to query Gemini: $e';
  }
}

Future<String> fetchTextFromUrl(String url) async {
  try {
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      // Parse the HTML document
      var document = parse(response.body);
      // Extract the text from the body, removing all HTML tags
      String extractedText = document.body?.text ?? "Could not extract text.";
      
      // Optional: Clean up the text (remove excessive whitespace)
      extractedText = extractedText.replaceAll(RegExp(r'\s+'), ' ').trim();
      
      // Be mindful of length! Gemini has a token limit.
      // You might want to truncate the text if it's very long.
      if (extractedText.length > 10000) {
        extractedText = extractedText.substring(0, 10000) + '... [text truncated]';
      }
      return extractedText;
    } else {
      throw Exception('Failed to load page: ${response.statusCode}');
    }
  } catch (e) {
    return 'Error fetching URL: $e';
  }
}

Future<void> _searchByUrl(String url) async {
  setState(() { _isLoading = true; });

  try {
    // 1. Fetch the text content from the provided URL
    String articleText = await fetchTextFromUrl(url);

    // 2. Create a prompt for Gemini, including the fetched text
    final prompt = """
    Please fact-check the claims made in the following article text. Focus on the main factual assertions.

    Return a structured response with these fields:
    - **Risk**: (Low/Medium/High)
    - **Evidence Summary**: A concise summary of your factual findings.
    - **Key Claims**: Bullet points of the specific claims you found and assessed.
    - **Sources**: List of sources or reasoning used in your assessment.

    Article Text:
    "$articleText"
    """;

    // 3. Send the prompt to Gemini using your existing _queryGeminiAI function
    final geminiResponse = await _queryGeminiAI(prompt); // Your existing text function
    final geminiFact = _formatGeminiResponseAsFactCheck("Article from $url", geminiResponse);

    setState(() {
      _factChecks = [geminiFact];
    });

  } catch (e) {
    setState(() {
      _errorMessage = 'Failed to process URL: $e';
    });
  } finally {
    setState(() { _isLoading = false; });
  }
}

  Future<void> _pickMedia() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedMedia = pickedFile;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: ${e.toString()}')),
      );
    }
  }

Future<String?> _uploadMedia() async {
  try {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    if (_selectedMedia == null) return null;

    // Use consistent bucket name throughout
    const String bucketName = 'post_media';

    // 1. Check if bucket exists and create if needed
    try {
      final buckets = await _supabase.storage.listBuckets();
      final bucketExists = buckets.any((bucket) => bucket.name == bucketName);
      
      if (!bucketExists) {
        throw Exception('Bucket does not exist');
      }
      print('✅ Bucket exists');
    } catch (e) {
      print('📦 Creating bucket...');
      try {
        await _supabase.storage.createBucket(
          bucketName,
          const BucketOptions(public: true), // Make bucket public for easier access
        );
        print('✅ Bucket created successfully');
      } catch (createError) {
        print('❌ Failed to create bucket: $createError');
        // Continue anyway - bucket might already exist
      }
    }

    // 2. Generate file path and name (consistent naming)
    final fileExtension = path.extension(_selectedMedia!.name);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}$fileExtension';
    final filePath = '${user.id}/$fileName'; // Simplified path structure

    print('📁 Uploading to bucket: $bucketName');
    print('📁 Uploading to path: $filePath');
    print('🔍 File extension: $fileExtension');

    // 3. Read file bytes using XFile methods (platform-agnostic)
    final Uint8List fileBytes = await _selectedMedia!.readAsBytes();
    print('📊 File size: ${fileBytes.length} bytes');

    // 4. Determine content type
    String contentType;
    switch (fileExtension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        contentType = 'image/jpeg';
        break;
      case '.png':
        contentType = 'image/png';
        break;
      case '.gif':
        contentType = 'image/gif';
        break;
      case '.webp':
        contentType = 'image/webp';
        break;
      default:
        contentType = 'image/jpeg'; // fallback
    }

    print('🎭 Content type: $contentType');

    // 5. Upload file to Supabase Storage
    final uploadResponse = await _supabase.storage
        .from(bucketName)
        .uploadBinary(
          filePath,
          fileBytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
            cacheControl: '3600',
          ),
        );

    print('✅ Upload successful: $uploadResponse');

    // 6. Get and return public URL
    final publicUrl = _supabase.storage
        .from(bucketName)
        .getPublicUrl(filePath);

    print('🔗 Public URL: $publicUrl');
    return publicUrl;

  } catch (e, stackTrace) {
    print('❌ Error uploading media: $e');
    print('📋 Stack trace: $stackTrace');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload media: ${e.toString()}')),
      );
    }
    return null;
  }
}
Future<void> _postThisMedia() async {
  // if (_textController.text.isEmpty || _factChecks.isEmpty) {
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     const SnackBar(content: Text("No claim or fact-check data to post!")),
  //   );
  //   return;
  // }
if(_selectedMedia == null) {
  final addMedia = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Add Media"),
      content: const Text("Would you like to add an image to this post?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("No"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text("Yes"),
        ),
      ],
    ),
  );

  if (addMedia == true) {
    await _pickMedia();
    if (_selectedMedia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No image selected")),
      );
      return;
    }
  }
}

  setState(() => _isLoading = true);

  try {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    String? mediaUrl;
    
    // Upload media if selected
    if (_selectedMedia != null) {
      print('🔄 Starting media upload...');
      mediaUrl = await _uploadMedia();
      if (mediaUrl == null) {
        throw Exception('Failed to upload media');
      }
      print('✅ Media uploaded successfully: $mediaUrl');
    }

    final review = _factChecks[0]['claimReview']?[0] ?? {};
    
    // Prepare post data for posts table
    final postData = {
      "user_id": user.id,
      "claim": _textController.text,
      "rating": review['textualRating'] ?? 'Unrated',
      "risk_level": _riskLevel,
      "media_url": mediaUrl, // This will store the image URL in your posts table
      "evidence": {
        "sources": [
          {
            "name": review['publisher']?['name'] ?? 'Unknown',
            "url": review['url'] ?? '',
            "summary": "Automated fact-check from Google Fact Check Tools"
          }
        ],
        "claims": _factChecks,
        "counterpoints": _getCounterpoints(review['textualRating'])
      },
      "created_at": DateTime.now().toIso8601String(),
    };

    print('📝 Inserting post data: ${postData.keys.join(", ")}');
    
    // Insert into posts table
    final response = await _supabase
        .from('posts')
        .insert(postData)
        .select(); // Add select() to get the inserted data back

    print('✅ Post inserted successfully: ${response.length} row(s)');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Fact-check posted successfully!"),
          backgroundColor: Colors.green,
        ),
      );
    }
    
    // Clear form
    _textController.clear();
    setState(() {
      _factChecks = [];
      _selectedMedia = null;
      _riskLevel = 'Medium';
    });

  } catch (e, stackTrace) {
    print('❌ Error posting: $e');
    print('📋 Stack trace: $stackTrace');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error posting: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    setState(() => _isLoading = false);
  }
}
  List<String> _getCounterpoints(String? rating) {
    final lowerRating = rating?.toLowerCase() ?? '';
    if (lowerRating.contains('false')) {
      return ["This claim has been widely debunked by experts"];
    } else if (lowerRating.contains('misleading')) {
      return ["This claim contains partial truths taken out of context"];
    }
    return ["Multiple sources confirm this claim"];
  }

  Widget _buildRiskLevelSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          const Text("Risk Level:", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          ChoiceChip(
            label: const Text("Low"),
            selected: _riskLevel == 'Low',
            onSelected: (selected) => setState(() => _riskLevel = 'Low'),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text("Medium"),
            selected: _riskLevel == 'Medium',
            onSelected: (selected) => setState(() => _riskLevel = 'Medium'),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text("High"),
            selected: _riskLevel == 'High',
            onSelected: (selected) => setState(() => _riskLevel = 'High'),
          ),
        ],
      ),
    );
  }

  void _showRiskLevelInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Risk Level Guide"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("• High: False claims with potential real-world harm"),
            SizedBox(height: 8),
            Text("• Medium: Misleading or exaggerated claims"),
            SizedBox(height: 8),
            Text("• Low: Minor inaccuracies or true claims"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Color _getRatingColor(String? rating) {
    if (rating == null) return Colors.grey;
    final lowerRating = rating.toLowerCase();
    if (lowerRating.contains('true')) return Colors.green;
    if (lowerRating.contains('false')) return Colors.red;
    if (lowerRating.contains('misleading')) return Colors.orange;
    return Colors.grey;
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Fact Checker"),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showRiskLevelInfo(context),
          )
        ],
      ),
      body: Container(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Text(
                  "Newsgram - Fact Checking",
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),
                TextField(
                  autofocus: false,
                  controller: _textController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    hintText: "Paste link or text to fact check the news",
                    prefixIcon: GestureDetector(onTap: () {
                      _pickMedia();
                      //_searchByImage(_selectedMedia!);
                    },child: Icon(Icons.fact_check_outlined)),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () {
                        if (_textController.text.isNotEmpty) {
                          if(_textController.text.startsWith("http")){
                            _searchByUrl(_textController.text);
                          }else{
                            _searchByText(_textController.text);
                            }
                        }else if (_selectedMedia != null) {
                          _searchByImage(_selectedMedia!);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Please enter text or select an image to fact-check.")),
                          );
                        }
                      },
                    ),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 20),
                if (_factChecks.isNotEmpty) _buildRiskLevelSelector(),
                if (_selectedMedia != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: kIsWeb
                        ? Image.network(
                            _selectedMedia!.path,
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            File(_selectedMedia!.path),
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                  ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _postThisMedia,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("POST FACT-CHECK", style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 20),
                if (_isLoading)
                  const CircularProgressIndicator()
                else if (_errorMessage != null)
                 SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Text(
            _errorMessage!,
            style: TextStyle(color: Colors.red[700]),
          ),
        )
        
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: _factChecks.length,
                      itemBuilder: (context, index) {
                        final claim = _factChecks[index];
                        final review = claim['claimReview']?[0];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            title: Text(claim['text'] ?? 'No claim text'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (review != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Rating: ${review['textualRating'] ?? 'Unknown'}',
                                    style: TextStyle(
                                      color: _getRatingColor(review['textualRating']),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'By: ${review['publisher']?['name'] ?? 'Unknown source'}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ],
                            ),
                            trailing: Icon(
                              Icons.arrow_forward,
                              color: Colors.grey[600],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 