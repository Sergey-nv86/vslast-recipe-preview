import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RecipeTechCardsScreen extends StatefulWidget {
  const RecipeTechCardsScreen({super.key});
  @override
  State<RecipeTechCardsScreen> createState() => _RecipeTechCardsScreenState();
}

class _RecipeTechCardsScreenState extends State<RecipeTechCardsScreen> {
  static const bg=Color(0xFFF8F4EE), brown=Color(0xFF8B5E3C), dark=Color(0xFF3B281F), muted=Color(0xFF806F65);
  final db=Supabase.instance.client;
  List<Map<String,dynamic>> cards=[];
  bool busy=true;
  String? error;
  @override void initState(){super.initState();load();}

  Future<void> load() async {
    setState((){busy=true;error=null;});
    try{
      final data=await db.from('recipe_tech_cards').select('id,name,yield_quantity,yield_unit,total_cost,calories_per_100,protein_per_100,fat_per_100,carbs_per_100,nutrition_status,calculation_status,created_at').order('created_at',ascending:false);
      if(mounted)setState(()=>cards=(data as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList());
    }catch(e){if(mounted)setState(()=>error='Не удалось загрузить карты: '+e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  String money(num? n)=>n==null?'не рассчитана':n.toStringAsFixed(2).replaceAll('.',',')+' ₽';

  Future<void> details(Map<String,dynamic> card) async {
    try{
      final data=await db.from('recipe_tech_card_items').select('ingredient_name_snapshot,quantity,unit,net_quantity,loss_percent,line_cost,notes,sort_order').eq('recipe_id',card['id']).order('sort_order');
      if(!mounted)return;
      await showModalBottomSheet<void>(context:context,isScrollControlled:true,backgroundColor:bg,builder:(ctx)=>SafeArea(child:Padding(padding:const EdgeInsets.all(18),child:DraggableScrollableSheet(expand:false,initialChildSize:0.82,builder:(ctx,scroll)=>ListView(controller:scroll,children:[
        Text(card['name'].toString(),style:const TextStyle(fontSize:22,fontWeight:FontWeight.w700,color:dark)),
        const SizedBox(height:8),
        Text('Выход: '+(card['yield_quantity']?.toString()??'—')+' '+(card['yield_unit']?.toString()??'')+' · Себестоимость: '+money(card['total_cost'] as num?),style:const TextStyle(color:muted)),
        const SizedBox(height:16),
        const Text('Состав',style:TextStyle(fontWeight:FontWeight.w700,color:dark)),
        ...(data as List).map((e){final x=Map<String,dynamic>.from(e as Map);return ListTile(contentPadding:EdgeInsets.zero,title:Text(x['ingredient_name_snapshot'].toString()),subtitle:Text(x['quantity'].toString()+' '+x['unit'].toString()),trailing:Text(money(x['line_cost'] as num?)));}),
        const Divider(),
        const Text('КБЖУ на 100 г',style:TextStyle(fontWeight:FontWeight.w700,color:dark)),
        Text('К '+(card['calories_per_100']?.toString()??'—')+' · Б '+(card['protein_per_100']?.toString()??'—')+' · Ж '+(card['fat_per_100']?.toString()??'—')+' · У '+(card['carbs_per_100']?.toString()??'—'),style:const TextStyle(color:muted)),
      ])))));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Не удалось открыть карту: '+e.toString())));}
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:bg,
    appBar:AppBar(backgroundColor:bg,elevation:0,title:const Text('Технологические карты',style:TextStyle(color:dark,fontWeight:FontWeight.w700)),iconTheme:const IconThemeData(color:brown),actions:[IconButton(onPressed:load,icon:const Icon(Icons.refresh))]),
    body:busy?const Center(child:CircularProgressIndicator(color:brown)):error!=null?Center(child:Padding(padding:const EdgeInsets.all(24),child:Text(error!,textAlign:TextAlign.center))):cards.isEmpty?const Center(child:Text('Пока нет сохранённых технологических карт.')):RefreshIndicator(onRefresh:load,child:ListView.builder(padding:const EdgeInsets.all(16),itemCount:cards.length,itemBuilder:(ctx,i){
      final c=cards[i];final ready=c['calculation_status']=='ready';
      return Card(color:Colors.white,elevation:0,margin:const EdgeInsets.only(bottom:10),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16),side:const BorderSide(color:Color(0xFFEADFD5))),child:ListTile(onTap:()=>details(c),title:Text(c['name'].toString(),style:const TextStyle(color:dark,fontWeight:FontWeight.w700)),subtitle:Text('Выход: '+(c['yield_quantity']?.toString()??'—')+' '+(c['yield_unit']?.toString()??'')+' · '+money(c['total_cost'] as num?),style:const TextStyle(color:muted)),trailing:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(ready?Icons.check_circle_outline:Icons.info_outline,color:ready?Colors.green:brown),Text(ready?'готова':'неполная',style:const TextStyle(fontSize:10,color:muted))])));
    })),
  );
}
