import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class WriteReviewPage extends StatefulWidget {
  final String destinationId;
  final String destinationName;

  const WriteReviewPage({
    super.key,
    required this.destinationId,
    required this.destinationName,
  });

  @override
  State<WriteReviewPage> createState() => _WriteReviewPageState();
}

class _WriteReviewPageState extends State<WriteReviewPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _reviewController = TextEditingController();
  int _rating = 0;
  bool _isLoading = false;
  String? _destinationImageUrl;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fetchDestinationImage();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
  }

  @override
  void dispose() {
    _reviewController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchDestinationImage() async {
    try {
      if (widget.destinationId.isNotEmpty) {
        final destDoc = await FirebaseFirestore.instance
            .collection('destinations')
            .doc(widget.destinationId)
            .get();
        if (destDoc.exists && mounted) {
          setState(() {
            _destinationImageUrl = destDoc.data()?['imageUrl'];
          });
        }
      }
    } catch (e) {
      // Handle image fetch error silently
    }
  }

  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate()) return;
    if (_rating == 0) {
      _showErrorSnackBar('Please select a rating by tapping the stars.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to write a review.');
      }

      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final authorName = userDoc.data()?['name'] ?? 'Anonymous';
      final authorImageUrl = userDoc.data()?['imageUrl'] ?? '';

      await FirebaseFirestore.instance.collection('reviews').add({
        'destinationId': widget.destinationId,
        'destinationName': widget.destinationName,
        'authorUid': user.uid,
        'authorName': authorName,
        'authorImageUrl': authorImageUrl,
        'rating': _rating,
        'reviewText': _reviewController.text.trim(),
        'createdAt': Timestamp.now(),
      });

      if (mounted) {
        _showSuccessSnackBar('Thank you for your review!');
        Navigator.of(context).pop();
      }
    } on FirebaseException catch (e) {
      _handleFirebaseError(e);
    } catch (e) {
      _showErrorSnackBar('An unexpected error occurred: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleFirebaseError(FirebaseException e) {
    String message;
    switch (e.code) {
      case 'internal':
        message = 'A server error occurred. Please try again later.';
        break;
      case 'permission-denied':
        message = 'You do not have permission to submit a review.';
        break;
      case 'failed-precondition':
        message =
            'Connection to the server failed. Please check your internet connection.';
        break;
      default:
        message = 'An error occurred. Please try again.';
    }
    _showErrorSnackBar(message);
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    _animationController.forward();
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    Center(child: _buildStarRating()),
                    const SizedBox(height: 24),
                    _buildReviewForm(),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 250.0,
      pinned: true,
      stretch: true,
      backgroundColor: Theme.of(context).primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Review ${widget.destinationName}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(blurRadius: 10, color: Colors.black)],
          ),
        ),
        background: _destinationImageUrl == null
            ? Container(color: Colors.grey)
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    _destinationImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Container(color: Colors.grey),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.6),
                          Colors.transparent
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.center,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Text(
      'How was your experience?',
      style: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildStarRating() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        return GestureDetector(
          onTap: () => setState(() => _rating = index + 1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(4.0),
            child: Icon(
              index < _rating ? Icons.star_rounded : Icons.star_border_rounded,
              color: Colors.amber,
              size: 48,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildReviewForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _reviewController,
            maxLines: 5,
            style: const TextStyle(color: Colors.black87),
            decoration: InputDecoration(
              hintText: 'Share your experience...',
              hintStyle: TextStyle(color: Colors.grey[600]),
              fillColor: Colors.white,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please share some thoughts.';
              }
              if (value.trim().length < 10) {
                return 'Your review must be at least 10 characters.';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _isLoading
                  ? const SizedBox.shrink()
                  : const Icon(Icons.send_rounded),
              label: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 3, color: Colors.white),
                    )
                  : const Text('Submit Review'),
              onPressed: _isLoading ? null : _submitReview,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                textStyle:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                elevation: 5,
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shadowColor: Theme.of(context).primaryColor.withOpacity(0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

