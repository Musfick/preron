import 'package:flutter/material.dart';
import 'package:preron/service/ussd_service.dart';
import 'package:preron/widgets/widgets.dart';
import 'package:toggle_switch/toggle_switch.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  List<Map<String, dynamic>> _simCards = [];
  Map<String, dynamic>? _selectedSimCard;

  @override
  void initState() {
    loadSimCards();
    super.initState();
  }

  Future<void> loadSimCards() async {
    try{
      final simCards = await UssdService.getSimCards();
      final selectedSim = await UssdService.getSelectedSim();
      print(selectedSim);
      if(mounted){
        setState(() {
          _simCards = simCards;
          _selectedSimCard = selectedSim;
        });
      }
    }catch(e){
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {

    final initialLabelIndex = _simCards.isEmpty || _selectedSimCard == null ? 0 : _simCards.indexWhere((e) => e["displayName"] == _selectedSimCard?["displayName"]);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("preron.", style: Theme.of(context).textTheme.headlineLarge,),
                        SizedBox(height: 16,),
                        Text(
                          "bKash but Offline: Cashout, Send Money, Balance Check Without the Internet.",
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                  if(_simCards.isNotEmpty)Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18)
                      ),
                      padding: EdgeInsets.all(8),
                      child: ToggleSwitch(
                        minWidth: 120,
                        cornerRadius: 14.0,
                        radiusStyle: true,
                        inactiveBgColor: Colors.grey.shade100,
                        inactiveFgColor: Colors.black54,
                        activeFgColor: Colors.white,
                        activeBgColor: [
                          Colors.black,
                        ],
                        initialLabelIndex: initialLabelIndex,
                        totalSwitches: _simCards.length,
                        labels: _simCards.map((e) => e["displayName"].toString()).toList(),
                        onToggle: (index) {
                          if(index != null){
                            setState(() {
                              _selectedSimCard = _simCards[index];
                            });
                            UssdService.setSelectedSim(_simCards[index]);
                          }
                        },
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white
            ),
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                HomeAction(
                  title: "bkash Cashout",
                  onAction: (){
                    Navigator.pushNamed(context, '/cashout');
                  },
                ),
                SizedBox(height: 16,),
                HomeAction(
                  title: "bkash Send Money",
                  onAction: (){
                    Navigator.pushNamed(context, '/send-money');
                  },
                ),
                SizedBox(height: 16,),
                HomeAction(
                  title: "bksah Balance",
                  onAction: (){
                    Navigator.pushNamed(context, '/balance');
                  },
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

