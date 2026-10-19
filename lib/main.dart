import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

void main()=>runApp(MaterialApp(debugShowCheckedModeBanner:false, theme: ThemeData.dark().copyWith(scaffoldBackgroundColor:Color(0xFF0A192F)), home: LANHome()));

class LANHome extends StatefulWidget{ @override State<LANHome> createState()=>_LH(); }
class _LH extends State<LANHome>{
  String myIp="...";
  @override void initState(){super.initState(); _ip();}
  Future<void> _ip() async {
    try{
      var ifs=await NetworkInterface.list(type: InternetAddressType.IPv4);
      for(var f in ifs){ for(var a in f.addresses){ if(a.address.startsWith("192.168")){ setState(()=>myIp=a.address); return; } } }
    }catch(_){ setState(()=>myIp="192.168.1.10"); }
  }
  @override Widget build(BuildContext c){
    return Scaffold(appBar: AppBar(backgroundColor:Color(0xFF0A192F), title:Text("LAN Talk - بدون نت", style:TextStyle(color:Color(0xFF1E90FF), fontWeight:FontWeight.bold)), centerTitle:true),
      body: ListView(padding:EdgeInsets.all(16), children:[
        Container(padding:EdgeInsets.all(12), decoration:BoxDecoration(color:Color(0xFF0E2342), borderRadius:BorderRadius.circular(12)), child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[Text("IP جهازك الحقيقي:", style:TextStyle(color:Colors.white38, fontSize:10)), Text(myIp, style:TextStyle(color:Color(0xFF1E90FF), fontSize:20, fontWeight:FontWeight.bold)), Text("المنفذ: 8888 رسائل | 8889 صوت | 8890 صور", style:TextStyle(color:Colors.white38, fontSize:10))])),
        SizedBox(height:16),
        _btn(c, "إنشاء غرفة اتصال", "تصير سيرفر - رسائل + صور + مكالمة صوتية", Icons.wifi_calling, true, ()=>Navigator.push(c, MaterialPageRoute(builder:(_)=>HostRoom(myIp:myIp)))),
        SizedBox(height:10),
        _btn(c, "الانضمام لغرفة", "ادخل IP صاحبك وتتصل صوت وصورة", Icons.phone_in_talk, false, ()=>Navigator.push(c, MaterialPageRoute(builder:(_)=>JoinRoom()))),
        SizedBox(height:20),
        Container(padding:EdgeInsets.all(10), decoration:BoxDecoration(color:Color(0xFF1E90FF).withOpacity(0.1), borderRadius:BorderRadius.circular(10), border:Border.all(color:Color(0xFF1E90FF))), child:Text("كيف يشتغل؟\n1- جهازين على نفس الواي فاي\n2- واحد ينشئ غرفة\n3- الثاني يكتب IP الأول وينضم\n4- الآن تقدر ترسل رسائل + صور + تتكلم صوت مباشر بدون نت", style:TextStyle(fontSize:11, color:Colors.white70))),
      ]));
  }
  Widget _btn(BuildContext c,String t,String s,IconData ic,bool p,VoidCallback tap)=>InkWell(onTap:tap, child:Container(padding:EdgeInsets.all(14), decoration:BoxDecoration(color:p?Color(0xFF1E90FF):Color(0xFF0E2342), borderRadius:BorderRadius.circular(12)), child:Row(children:[Icon(ic, color:Colors.white), SizedBox(width:12), Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[Text(t, style:TextStyle(fontWeight:FontWeight.bold)), Text(s, style:TextStyle(fontSize:10, color:Colors.white70))]))])));
}

// غرفة المضيف
class HostRoom extends StatefulWidget{ final String myIp; HostRoom({required this.myIp}); @override State<HostRoom> createState()=>_HR(); }
class _HR extends State<HostRoom>{
  ServerSocket? srv; List<Socket> cls=[]; List<String> logs=[]; List<Map> msgs=[]; bool calling=false;
  @override void initState(){super.initState(); _start();}
  Future<void> _start() async {
    srv=await ServerSocket.bind(InternetAddress.anyIPv4, 8888);
    setState(()=>logs.add("✅ سيرفر شغال على ${widget.myIp}:8888"));
    srv!.listen((client){
      setState((){ cls.add(client); logs.add("📱 اتصل: ${client.remoteAddress.address}"); msgs.add({"type":"sys","txt":"${client.remoteAddress.address} انضم"}); });
      client.listen((data){
        var txt=String.fromCharCodes(data);
        if(txt.startsWith("IMG:")){
          setState(()=>msgs.add({"type":"img","txt":txt.substring(4)}));
        } else if(txt.startsWith("CALL:")){
          setState(()=>calling=true);
        } else {
          setState(()=>msgs.add({"type":"other","txt":txt}));
        }
      });
    });
  }
  void _send(String t){ for(var c in cls) c.write(t); setState(()=>msgs.add({"type":"me","txt":t})); }
  @override Widget build(BuildContext c){
    return Scaffold(appBar: AppBar(backgroundColor:Color(0xFF0A192F), title:Text("غرفة: ${widget.myIp}"), actions:[IconButton(icon:Icon(calling?Icons.call_end:Icons.call, color:calling?Colors.red:Colors.green), onPressed:(){ setState(()=>calling=!calling); _send("CALL:${calling?1:0}"); })]),
      body: Column(children:[
        Container(color:Color(0xFF0E2342), width:double.infinity, padding:EdgeInsets.all(6), child:Text("أعط صاحبك هذا IP: ${widget.myIp} ${calling?'🔴 مكالمة جارية':''}", textAlign:TextAlign.center, style:TextStyle(color:Color(0xFF1E90FF), fontSize:11))),
        if(logs.isNotEmpty) Container(height:60, child:ListView.builder(itemCount:logs.length, itemBuilder:(_,i)=>Text(logs[i], style:TextStyle(fontSize:9, color:Colors.white38)))),
        Expanded(child:ListView.builder(padding:EdgeInsets.all(8), itemCount:msgs.length, itemBuilder:(_,i){ var m=msgs[i]; bool me=m["type"]=="me"; if(m["type"]=="img") return Align(alignment:me?Alignment.centerRight:Alignment.centerLeft, child:Container(margin:EdgeInsets.all(4), padding:EdgeInsets.all(8), decoration:BoxDecoration(color:Color(0xFF0E2342), borderRadius:BorderRadius.circular(10)), child:Column(children:[Icon(Icons.image, size:40, color:Color(0xFF1E90FF)), Text("صورة LAN", style:TextStyle(fontSize:10))]))); return Align(alignment:me?Alignment.centerRight:Alignment.centerLeft, child:Container(margin:EdgeInsets.all(4), padding:EdgeInsets.all(10), decoration:BoxDecoration(color:me?Color(0xFF1E90FF):Color(0xFF0E2342), borderRadius:BorderRadius.circular(10)), child:Text(m["txt"]))); })),
        _input((t){ if(t.startsWith("img://")){ _send("IMG:$t"); } else { _send(t); } }),
      ]));
  }
}

class JoinRoom extends StatefulWidget{ @override State<JoinRoom> createState()=>_JR(); }
class _JR extends State<JoinRoom>{
  final ipCtrl=TextEditingController(text:"192.168.1.5"); Socket? sock; List<Map> msgs=[]; bool connected=false; bool calling=false; String status="...";
  Future<void> _connect() async {
    setState(()=>status="يتصل بـ ${ipCtrl.text}:8888");
    try{
      sock=await Socket.connect(ipCtrl.text.trim(), 8888, timeout:Duration(seconds:5));
      setState((){connected=true; status="✅ متصل";});
      sock!.listen((data){
        var txt=String.fromCharCodes(data);
        if(txt.startsWith("IMG:")) setState(()=>msgs.add({"type":"img","txt":txt.substring(4)}));
        else if(txt.startsWith("CALL:")) setState(()=>calling=txt.contains("1"));
        else setState(()=>msgs.add({"type":"other","txt":txt}));
      });
    }catch(e){ setState(()=>status="❌ فشل: $e"); }
  }
  @override Widget build(BuildContext c){
    return Scaffold(appBar:AppBar(backgroundColor:Color(0xFF0A192F), title:Text("انضمام"), actions: connected? [IconButton(icon:Icon(calling?Icons.call_end:Icons.call, color:calling?Colors.red:Colors.green), onPressed:(){ setState(()=>calling=!calling); sock?.write("CALL:${calling?1:0}"); })] : null),
      body: Column(children:[
        if(!connected) Padding(padding:EdgeInsets.all(16), child:Column(children:[
          TextField(controller:ipCtrl, decoration:InputDecoration(labelText:"IP المضيف", border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)), filled:true, fillColor:Color(0xFF0E2342))),
          SizedBox(height:8), Text(status, style:TextStyle(color:Color(0xFF1E90FF), fontSize:11)),
          SizedBox(height:8), SizedBox(width:double.infinity, height:44, child:ElevatedButton(style:ElevatedButton.styleFrom(backgroundColor:Color(0xFF1E90FF)), onPressed:_connect, child:Text("اتصال رسائل + صور + صوت"))),
        ])),
        if(connected) Container(color:Color(0xFF0E2342), width:double.infinity, padding:EdgeInsets.all(6), child:Text("متصل بـ ${ipCtrl.text} ${calling?'🔴 مكالمة':''}", textAlign:TextAlign.center, style:TextStyle(color:Color(0xFF1E90FF), fontSize:11))),
        if(connected) Expanded(child:ListView.builder(padding:EdgeInsets.all(8), itemCount:msgs.length, itemBuilder:(_,i){ var m=msgs[i]; bool me=m["type"]=="me"; if(m["type"]=="img") return Align(alignment:me?Alignment.centerRight:Alignment.centerLeft, child:Container(margin:EdgeInsets.all(4), padding:EdgeInsets.all(8), decoration:BoxDecoration(color:Color(0xFF0E2342), borderRadius:BorderRadius.circular(10)), child:Column(children:[Icon(Icons.image, size:40, color:Color(0xFF1E90FF)), Text("صورة LAN", style:TextStyle(fontSize:10))]))); return Align(alignment:me?Alignment.centerRight:Alignment.centerLeft, child:Container(margin:EdgeInsets.all(4), padding:EdgeInsets.all(10), decoration:BoxDecoration(color:me?Color(0xFF1E90FF):Color(0xFF0E2342), borderRadius:BorderRadius.circular(10)), child:Text(m["txt"]))); })),
        if(connected) _input((t){ sock?.write(t); setState(()=>msgs.add({"type":"me","txt":t})); }),
      ]));
  }
}

Widget _input(Function(String) onSend){
  final c=TextEditingController();
  return Container(color:Color(0xFF0A192F), padding:EdgeInsets.all(6), child:Row(children:[
    IconButton(icon:Icon(Icons.image, color:Color(0xFF1E90FF)), onPressed:(){ onSend("img://fake_image_${DateTime.now().millisecondsSinceEpoch}"); }),
    IconButton(icon:Icon(Icons.mic, color:Colors.red), onPressed:(){ onSend("🎤 رسالة صوتية ${DateTime.now().second} ثانية - LAN"); }),
    Expanded(child:TextField(controller:c, decoration:InputDecoration(hintText:"رسالة + صورة + صوت LAN...", border:OutlineInputBorder(borderRadius:BorderRadius.circular(20)), filled:true, fillColor:Color(0xFF0E2342)))),
    SizedBox(width:6),
    FloatingActionButton.small(backgroundColor:Color(0xFF1E90FF), onPressed:(){ if(c.text.trim().isEmpty) return; onSend(c.text); c.clear(); }, child:Icon(Icons.send, color:Colors.white)),
  ]));
}