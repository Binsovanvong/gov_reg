import 'package:flutter/material.dart';

class VerifySuccessScreen extends StatelessWidget {
  const VerifySuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                const SizedBox(height: 40),

                // Title
                const Text(
                  'ការស្នើរសុំ',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                // Check icon
                Container(
                  width: 150,
                  height: 150,
                  decoration: const BoxDecoration(
                    color: Color(0xFF24345A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 100,
                  ),
                ),

                SizedBox(height: 20),

                // Success text
                const Text(
                  'ការចុះឈ្មោះទទួលបានជោគជ័យ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'ពាក្យស្នើសុំរបស់អ្នកត្រូវបានបញ្ជូនដោយជោគជ័យយើងនឹង'
                  '\nពិនិត្យមើលព័ត៌មានលម្អិតរបស់អ្នកហើយជូនដំណឹងដល់អ្នក'
                  '\nក្នុងពេលឆាប់ៗនេះ។',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black45,
                    height: 1.8,
                  ),
                ),

                const SizedBox(height: 30),

                // Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            'ស្ថានភាព',
                            style: TextStyle(fontSize: 14),
                          ),
                          Row(
                            children: [
                              Icon(Icons.circle,
                                  size: 10, color: Colors.green),
                              SizedBox(width: 6),
                              Text(
                                'បានផ្ទៀងផ្ទាត់',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                       Divider(height: 24),

                      // Phone number
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children:  [
                          Text(
                            'អត្តលេខ',
                            style: TextStyle(fontSize: 16),
                          ),
                          Row(
                            children: [
                              Text(
                                '05112004',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 8),
                              IconButton(onPressed: () {
                                
                              }, icon: Icon(Icons.copy),color: Color(0xFF24345A),)
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Continue button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF24345A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text(
                      'ត្រឡប់ក្រោយ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Back link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.download,color: Color(0xFF24345A),),
                    TextButton(
                      onPressed: () {
                        
                      },
                      style: ElevatedButton.styleFrom(
                      foregroundColor: Color(0xFF24345A),     
                    ),
                      child:  Text(
                        'ត្រឡប់ទៅមុខមុន',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
