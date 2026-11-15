import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RecipeTechEditorScreen extends StatefulWidget {
  const RecipeTechEditorScreen({super.key, this.initialText = ''});
  final String initialText;
  @override
  State<RecipeTechEditorScreen> createState() => _RecipeTechEditorScreenState();
}

class _RecipeTechEditorScreenState extends State<RecipeTechEditorScreen> {
  static const bg=Color(0xFFF8F4EE), brown=Color(0xFF8B5E3C), dark=Color(0xFF3B281F), muted=Color(0xFF806F65);
  final db=Supabase.instance.client;
  final name=TextEditingController();
  final yieldController=TextEditingController();
  final technology=TextEditingController();
  final storage=TextEditingController();
  final sourceText=TextEditingController();
  List<Map<String,dynamic>> catalog=[];
  final lines=<_DraftLine>[];
  bool loading=true, saving=false;
  String yieldUnit='g';
  String? error;

  @override void initState(){super.initState();sourceText.text=widget.initialText;loadCatalog();}
  @override void dispose(){name.dispose();yieldController.dispose();technology.dispose();storage.dispose();sourceText.dispose();for(final x in lines){x.dispose();}super.dispose();}

  Future<void> loadCatalog() async {
    try{
      final data=await db.from('ingredients').select('id,name,base_unit,calories_per_100,protein_per_100,fat_per_100,carbs_per_100,needs_review,ingredient_prices(price_per_base_unit)').order('name');
      if(mounted)setState(()=>catalog=(data as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList());
    }catch(e){if(mounted)setState(()=>error='Не удалось загрузить ингредиенты: '+e.toString());}
    finally{if(mounted)setState(()=>loading=false);}
  }

  String unitName(String unit)=>unit=='ml'?'мл':unit=='pcs'?'шт':'г';
  String money(num n)=>n.toStringAsFixed(2).replaceAll('.',',');
  num? number(TextEditingController c)=>num.tryParse(c.text.trim().replaceAll(',','.'));

  Future<void> addIngredient() async {
    if(catalog.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Сначала заполните справочник сырья')));return;}
    Map<String,dynamic>? selected=catalog.first;
    final quantity=TextEditingController(text:'100');
    final accepted=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh)=>AlertDialog(
      title:const Text('Добавить ингредиент'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        DropdownButtonFormField<String>(initialValue:selected!['id'].toString(),isExpanded:true,decoration:const InputDecoration(labelText:'Ингредиент',border:OutlineInputBorder()),items:catalog.map((x)=>DropdownMenuItem(value:x['id'].toString(),child:Text(x['name'].toString(),overflow:TextOverflow.ellipsis))).toList(),onChanged:(id)=>refresh(()=>selected=catalog.firstWhere((x)=>x['id'].toString()==id))),
        const SizedBox(height:10),
        TextField(controller:quantity,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:'Количество, '+unitName(selected['base_unit'].toString()),border:const OutlineInputBorder())),
      ]),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Отмена')),FilledButton(style:FilledButton.styleFrom(backgroundColor:brown),onPressed:()=>Navigator.pop(ctx,true),child:const Text('Добавить'))],
    )));
    final q=number(quantity);quantity.dispose();
    if(accepted!=true||selected==null||q==null||q<=0)return;
    setState(()=>lines.add(_DraftLine(ingredient:selected!,quantity:q.toString())));
  }

  Map<String,dynamic> calculate() {
    double cost=0;bool allPrices=true;bool nutritionComplete=lines.isNotEmpty;bool estimated=false;
    double calories=0,protein=0,fat=0,carbs=0;
    for(final line in lines){
      final q=number(line.quantity);final ingredient=line.ingredient;
      if(q==null||q<=0){allPrices=false;nutritionComplete=false;continue;}
      final prices=ingredient['ingredient_prices'] as List? ?? [];
      final price=prices.isEmpty?null:Map<String,dynamic>.from(prices.first as Map)['price_per_base_unit'] as num?;
      if(price==null)allPrices=false;else cost+=q*price;
      if(ingredient['needs_review']==true)estimated=true;
      if(ingredient['base_unit']!='g'||['calories_per_100','protein_per_100','fat_per_100','carbs_per_100'].any((k)=>ingredient[k]==null)){
        nutritionComplete=false;
      }else{
        calories+=q/100*(ingredient['calories_per_100'] as num).toDouble();
        protein+=q/100*(ingredient['protein_per_100'] as num).toDouble();
        fat+=q/100*(ingredient['fat_per_100'] as num).toDouble();
        carbs+=q/100*(ingredient['carbs_per_100'] as num).toDouble();
      }
    }
    final y=number(yieldController);
    final yieldGrams=y==null?null:(yieldUnit=='kg'?y*1000:y);
    final nutrition=nutritionComplete&&yieldGrams!=null&&yieldGrams>0?{
      'calories':calories/yieldGrams*100,'protein':protein/yieldGrams*100,'fat':fat/yieldGrams*100,'carbs':carbs/yieldGrams*100
    }:null;
    return {'total_cost':allPrices?cost:null,'nutrition':nutrition,'nutrition_status':nutrition==null?'incomplete':estimated?'estimated':'calculated','calculation_status':allPrices&&lines.isNotEmpty?'ready':'needs_prices'};
  }

  Future<void> save() async {
    if(saving)return;
    if(name.text.trim().isEmpty||lines.isEmpty||number(yieldController)==null||number(yieldController)!<=0){
      setState(()=>error='Укажите название, выход и добавьте ингредиенты.');return;
    }
    if(lines.any((x)=>number(x.quantity)==null||number(x.quantity)!<=0)){
      setState(()=>error='Проверьте количество каждого ингредиента.');return;
    }
    setState(() { saving=true; error=null; });
    try{
      final calc=calculate();final nutrition=calc['nutrition'] as Map<String,double>?;
      final card=await db.from('recipe_tech_cards').insert({
        'name':name.text.trim(),'technology':technology.text.trim(),'storage_conditions':storage.text.trim().isEmpty?null:storage.text.trim(),
        'yield_quantity':number(yieldController),'yield_unit':yieldUnit,'total_cost':calc['total_cost'],
        'calories_per_100':nutrition?['calories'],'protein_per_100':nutrition?['protein'],'fat_per_100':nutrition?['fat'],'carbs_per_100':nutrition?['carbs'],
        'nutrition_status':calc['nutrition_status'],'calculation_status':calc['calculation_status'],'source_photo_count':0,'created_by':db.auth.currentUser?.id
      }).select('id').single();
      final rows=lines.asMap().entries.map((entry){
        final line=entry.value;final ingredient=line.ingredient;final q=number(line.quantity)!;
        final prices=ingredient['ingredient_prices'] as List? ?? [];
        final per=prices.isEmpty?null:Map<String,dynamic>.from(prices.first as Map)['price_per_base_unit'] as num?;
        return {'recipe_id':card['id'],'ingredient_id':ingredient['id'],'ingredient_name_snapshot':ingredient['name'],'quantity':q,'net_quantity':q,'unit':ingredient['base_unit'],'line_cost':per==null?null:q*per,'sort_order':entry.key};
      }).toList();
      await db.from('recipe_tech_card_items').insert(rows);
      if(!mounted)return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Технологическая карта сохранена')));
      Navigator.pop(context);
    }catch(e){if(mounted)setState(()=>error='Не удалось сохранить карту: '+e.toString());}
    finally{if(mounted)setState(()=>saving=false);}
  }

  @override
  Widget build(BuildContext context){
    final calc=calculate();final nutrition=calc['nutrition'] as Map<String,double>?;
    return Scaffold(
      backgroundColor:bg,
      appBar:AppBar(backgroundColor:bg,elevation:0,title:const Text('Новая технологическая карта',style:TextStyle(color:dark,fontWeight:FontWeight.w700)),iconTheme:const IconThemeData(color:brown),actions:[IconButton(onPressed:save,icon:const Icon(Icons.save_outlined))]),
      body:loading?const Center(child:CircularProgressIndicator(color:brown)):ListView(padding:const EdgeInsets.all(16),children:[
        _section('Основные сведения',Column(children:[
          TextField(controller:name,decoration:const InputDecoration(labelText:'Название изделия',border:OutlineInputBorder())),
          const SizedBox(height:9),
          Row(children:[Expanded(child:TextField(controller:yieldController,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Фактический выход',border:OutlineInputBorder()))),const SizedBox(width:8),SizedBox(width:110,child:DropdownButtonFormField<String>(initialValue:yieldUnit,decoration:const InputDecoration(labelText:'Единица',border:OutlineInputBorder()),items:const [DropdownMenuItem(value:'g',child:Text('г')),DropdownMenuItem(value:'kg',child:Text('кг'))],onChanged:(v)=>setState(()=>yieldUnit=v??'g')))]),
          const SizedBox(height:9),
          TextField(controller:technology,minLines:3,maxLines:8,decoration:const InputDecoration(labelText:'Технология приготовления',alignLabelWithHint:true,border:OutlineInputBorder())),
          const SizedBox(height:9),
          TextField(controller:storage,minLines:2,maxLines:4,decoration:const InputDecoration(labelText:'Условия и сроки хранения',alignLabelWithHint:true,border:OutlineInputBorder())),
        ])),
        const SizedBox(height:12),
        _section('Ингредиенты',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          if(lines.isEmpty)const Text('Добавьте ингредиенты из справочника. Для каждого укажите количество в базовой единице.',style:TextStyle(color:muted)),
          ...lines.asMap().entries.map((entry){final i=entry.key;final line=entry.value;final prices=line.ingredient['ingredient_prices'] as List? ?? [];final per=prices.isEmpty?null:Map<String,dynamic>.from(prices.first as Map)['price_per_base_unit'] as num?;return Padding(padding:const EdgeInsets.only(bottom:10),child:Row(children:[
            Expanded(flex:4,child:Text(line.ingredient['name'].toString(),style:const TextStyle(color:dark,fontWeight:FontWeight.w600))),
            SizedBox(width:92,child:TextField(controller:line.quantity,keyboardType:const TextInputType.numberWithOptions(decimal:true),onChanged:(_)=>setState((){}),decoration:InputDecoration(isDense:true,suffixText:unitName(line.ingredient['base_unit'].toString()),border:const OutlineInputBorder()))),
            const SizedBox(width:8),
            SizedBox(width:76,child:Text(per==null?'нет цены':money(number(line.quantity)==null?0:number(line.quantity)!*per)+' ₽',textAlign:TextAlign.end,style:TextStyle(fontSize:11,color:per==null?Colors.red:muted))),
            IconButton(onPressed:()=>setState(()=>lines.removeAt(i).dispose()),icon:const Icon(Icons.close,color:muted)),
          ]));}),
          OutlinedButton.icon(onPressed:addIngredient,icon:const Icon(Icons.add),label:const Text('Добавить ингредиент')),
        ])),
        const SizedBox(height:12),
        _section('Расчёт',Column(children:[
          _summary('Себестоимость всей рецептуры',calc['total_cost']==null?'неполная — проверьте цены':money(calc['total_cost'] as num)+' ₽'),
          _summary('Себестоимость на 1 кг',calc['total_cost']==null||number(yieldController)==null?'—':money((calc['total_cost'] as num)*1000/(yieldUnit=='kg'?number(yieldController)!*1000:number(yieldController)!))+' ₽'),
          _summary('КБЖУ на 100 г',nutrition==null?'недостаточно подтверждённых данных':'К '+nutrition['calories']!.toStringAsFixed(1)+' · Б '+nutrition['protein']!.toStringAsFixed(1)+' · Ж '+nutrition['fat']!.toStringAsFixed(1)+' · У '+nutrition['carbs']!.toStringAsFixed(1)),
          Text(calc['calculation_status']=='ready'?'Все цены найдены.':'Есть ингредиенты без цены — итоговая себестоимость не показывается.',style:const TextStyle(color:muted,fontSize:12)),
        ])),
        if(sourceText.text.trim().isNotEmpty)...[
          const SizedBox(height:12),
          _section('Исходный текст OCR',TextField(controller:sourceText,minLines:4,maxLines:12,decoration:const InputDecoration(border:OutlineInputBorder(),hintText:'Текст распознанного рецепта'))),
        ],
        if(error!=null)Padding(padding:const EdgeInsets.symmetric(vertical:10),child:Text(error!,style:const TextStyle(color:Colors.red))),
        const SizedBox(height:10),
        SizedBox(height:52,child:FilledButton(style:FilledButton.styleFrom(backgroundColor:brown),onPressed:saving?null:save,child:Text(saving?'Сохраняю…':'Сохранить технологическую карту'))),
      ]),
    );
  }

  Widget _section(String title,Widget child)=>Card(color:Colors.white,elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16),side:const BorderSide(color:Color(0xFFEADFD5))),child:Padding(padding:const EdgeInsets.all(15),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w700,color:dark)),const SizedBox(height:12),child])));
  Widget _summary(String label,String value)=>Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Row(children:[Expanded(child:Text(label,style:const TextStyle(color:muted,fontSize:13))),const SizedBox(width:10),Flexible(child:Text(value,textAlign:TextAlign.end,style:const TextStyle(color:dark,fontWeight:FontWeight.w600,fontSize:13)))]));
}

class _DraftLine {
  _DraftLine({required this.ingredient,required String quantity}):quantity=TextEditingController(text:quantity);
  final Map<String,dynamic> ingredient;
  final TextEditingController quantity;
  void dispose()=>quantity.dispose();
}
