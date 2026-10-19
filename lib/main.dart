import 'dart:io';
import 'package:flutter/material.dart';
void main()=>runApp(MaterialApp(debugShowCheckedModeBanner:false, theme:ThemeData.dark().copyWith(scaffoldBackgroundColor:Color(0xFF0A192F)), home: App()));

class App extends StatefulWidget{ @override State<App> createState()=>_AppS(); }
class _AppS extends State<App>{
  String ip="192.168.1.10";
  @override void initState(){super.initState(); _getIp();}
  Future<void> _getIp() async {
    try{
      var list=await NetworkInterface.list(type: InternetAddressType.IPv4);
      for(var i in list){ for(var a in i.addresses){ if(a.address.startsWith("192.168")){ setState(()=>ip=a.address); return; } } }
    }catch(_){}
  }
  @override Widget build(BuildContext c){
    return Scaffold(appBar:AppBar(backgroundColor:Color(0xFF0A192F), title:Text("LAN صوت وصورة ورسائل", style:TextStyle(color:Color(0xFF1E90FF), fontWeight:FontWeight.bold)), centerTitle:true),
      body:ListView(padding:EdgeInsets.all(16), children:[
        Container(padding:EdgeInsets.all(12), decoration:BoxDecoration(color:Color(0xFF0E2342), borderRadius:BorderRadius.circular(12)), child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[Text("IP الحقيقي:", style:TextStyle(color:Colors.white38, fontSize:10)), Text(ip, style:TextStyle(color:Color(0xFF1E90FF), fontSize:18, fontWeight:FontWeight.bold)), Text("بدون نت - LAN فقط", style:TextStyle(color:Colors.white38, fontSize:10))])),
        SizedBox(height:16),
        _b(c, "إنشاء اتصال LAN", "رسائل + صور + مكالمة صوتية", Icons.wifi, true, ()=>Navigator.push(c, MaterialPageRoute(builder:(_)=>Room(ip:ip, isHost:true)))),
        SizedBox(height:10),
        _b(c, "الانضمام", "ادخل IP صاحبك", Icons.search, false, ()=>Navigator.push(c, MaterialPageRoute(builder:(_)=>Room(ip:ip, isHost:false)))),
      ]));
  }
  Widget _b(BuildContext c,String t,String s,IconData ic,bool p,VoidCallback f)=>InkWell(onTap:f, child:Container(padding:EdgeInsets.all(14), decoration:BoxDecoration(color:p?Color(0xFF1E90FF):Color(0xFF0E2342), borderRadius:BorderRadius.circular(12)), child:Row(children:[Icon(ic), SizedBox(width:12), Column(crossAxisAlignment:CrossAxisAlignment.start, children:[Text(t, style:TextStyle(fontWeight:FontWeight.bold)), Text(s, style:TextStyle(fontSize:10, color:Colors.white70))])])));
}

class Room extends StatefulWidget{ final String ip; final bool isHost; Room({required this.ip, required this.isHost}); @override State<Room> createState()=>_RoomS(); }
class _RoomS extends State<Room>{
  ServerSocket? server; Socket? client; List<String> msgs=[]; final ctrl=TextEditingController(); final ipCtrl=TextEditingController(); String log=""; bool call=false;

  @override void initState(){super.initState(); ipCtrl.text=widget.ip; if(widget.isHost) _host();}

  Future<void> _host() async {
    try{
      server=await ServerSocket.bind(InternetAddress.anyIPv4, 8888);
      setState(()=>log="سيرفر شغال ${widget.ip}:8888");
      server!.listen((c){
        client=c;
        setState(()=>msgs.add("📱 انضم: ${c.remoteAddress.address}"));
        c.listen((d){ setState(()=>msgs.add("📩 ${String.fromCharCodes(d)}")); });
      });
    }catch(e){ setState(()=>log="خطأ: $e"); }
  }

  Future<void> _join() async {
    try{
      setState(()=>log="يتصل...");
      client=await Socket.connect(ipCtrl.text.trim(), 8888, timeout:Duration(seconds:4));
      setState(()=>log="متصل ✅");
      client!.listen((d){ setState(()=>msgs.add("📩 ${String.fromCharCodes(d)}")); });
    }catch(e){ setState(()=>log="فشل: $e"); }
  }

  void _send(String t){ client?.write(t); if(server!=null){ for(var c in [client]){ c?.write(t); } } setState(()=>msgs.add("أنت: $t")); }

  @override Widget build(BuildContext c){
    return Scaffold(appBar:AppBar(backgroundColor:Color(0xFF0A192F), title:Text(widget.isHost?"أنت السيرفر ${widget.ip}":"انضمام"), actions:[IconButton(icon:Icon(call?Icons.call_end:Icons.call, color:call?Colors.red:Colors.green), onPressed:(){ setState(()=>call=!call); _send(call?"🔴 بدأ مكالمة صوتية LAN":"🔴 أنهى المكالمة"); })]),
      body:Column(children:[
        Container(color:Color(0xFF0E2342), width:double.infinity, padding:EdgeInsets.all(6), child:Text(log.isEmpty?"IP: ${widget.ip}":log, textAlign:TextAlign.center, style:TextStyle(color:Color(0xFF1E90FF), fontSize:11))),
        if(!widget.isHost) Padding(padding:EdgeInsets.all(8), child:Row(children:[Expanded(child:TextField(controller:ipCtrl, decoration:InputDecoration(labelText:"IP المضيف", border:OutlineInputBorder(), filled:true, fillColor:Color(0xFF0E2342)))), SizedBox(width:6), ElevatedButton(style:ElevatedButton.styleFrom(backgroundColor:Color(0xFF1E90FF)), onPressed:_join, child:Text("اتصال"))])),
        if(call) Container(color:Colors.red.with