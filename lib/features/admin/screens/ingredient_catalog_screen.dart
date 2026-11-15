import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class IngredientCatalogScreen extends StatefulWidget {
  const IngredientCatalogScreen({super.key});
  @override
  State<IngredientCatalogScreen> createState() => _IngredientCatalogScreenState();
}

class _IngredientCatalogScreenState extends State<IngredientCatalogScreen> {
  static const bg=Color(0xFFF8F4EE), brown=Color(0xFF8B5E3C), dark=Color(0xFF3B281F), muted=Color(0xFF806F65);
  final db=Supabase.instance.client;
  final search=TextEditingController();
  List<Map<String,dynamic>> rows=[];
  bool busy=true;
  String? error;
  @override void initState(){super.initState();load();}
  @override void dispose(){search.dispose();super.dispose();}

  Future<void> load() async {
    setState((){busy=true;error=null;});
    try{
      final data=await db.from('ingredients').select('id,name,normalized_name,base_unit,calories_per_100,protein_per_100,fat_per_100,carbs_per_100,nutrition_source,needs_review,ingredient_prices(purchase_price,purchase_quantity,purchase_unit,price_per_base_unit,updated_at,supplier_name,price_source,price_valid_from,package_label)').order('name');
      if(mounted)setState(()=>rows=(data as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList());
    }catch(e){if(mounted)setState(()=>error='Не удалось загрузить справочник: '+e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }

  String normalize(String s)=>s.toLowerCase().replaceAll('ё','е').replaceAll(RegExp(r'[^а-яa-z0-9]+'),' ').trim().replaceAll(RegExp(r'\s+'),' ');
  String money(num? n)=>n==null?'не задана':n.toStringAsFixed(2).replaceAll('.',',')+' ₽';

  Future<void> edit([Map<String,dynamic>? row]) async {
    final name=TextEditingController(text:row?['name']?.toString()??'');
    final price=TextEditingController();
    final pack=TextEditingController(text:'1');
    final kcal=TextEditingController(text:row?['calories_per_100']?.toString()??'');
    final protein=TextEditingController(text:row?['protein_per_100']?.toString()??'');
    final fat=TextEditingController(text:row?['fat_per_100']?.toString()??'');
    final carbs=TextEditingController(text:row?['carbs_per_100']?.toString()??'');
    final source=TextEditingController(text:row?['nutrition_source']?.toString()??'');
    final priceRows=row?['ingredient_prices'] as List? ?? [];
    final currentPrice=priceRows.isEmpty?null:Map<String,dynamic>.from(priceRows.first as Map);
    final supplier=TextEditingController(text:currentPrice?['supplier_name']?.toString()??'');
    final priceSource=TextEditingController(text:currentPrice?['price_source']?.toString()??'');
    if(currentPrice!=null){price.text=currentPrice['purchase_price']?.toString()??'';pack.text=currentPrice['purchase_quantity']?.toString()??'1';}
    String base=row?['base_unit']?.toString()??'g';
    String purchaseUnit=base=='ml'?'l':base=='pcs'?'pcs':'kg';
    if(currentPrice!=null)purchaseUnit=currentPrice['purchase_unit']?.toString()??purchaseUnit;
    bool review=row?['needs_review']!=false;
    String? formError;
    final saved=await showDialog<bool>(context:context,barrierDismissible:false,builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh)=>AlertDialog(
      title:Text(row==null?'Новое сырьё':'Карточка сырья'),
      content:SizedBox(width:440,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:name,decoration:const InputDecoration(labelText:'Название ингредиента',border:OutlineInputBorder())),
        const SizedBox(height:9),
        DropdownButtonFormField<String>(initialValue:base,decoration:const InputDecoration(labelText:'Базовая единица',border:OutlineInputBorder()),items:const [DropdownMenuItem(value:'g',child:Text('грамм')),DropdownMenuItem(value:'ml',child:Text('миллилитр')),DropdownMenuItem(value:'pcs',child:Text('штука'))],onChanged:(v)=>refresh((){base=v??base;purchaseUnit=base=='ml'?'l':base=='pcs'?'pcs':'kg';})),
        const SizedBox(height:14),
        const Align(alignment:Alignment.centerLeft,child:Text('Закупочная цена',style:TextStyle(fontWeight:FontWeight.w700,color:dark))),
        const SizedBox(height:7),
        TextField(controller:price,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Цена упаковки, ₽',border:OutlineInputBorder())),
        const SizedBox(height:7),
        Row(children:[
          Expanded(child:TextField(controller:pack,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Количество в упаковке',border:OutlineInputBorder()))),
          const SizedBox(width:8),
          Expanded(child:DropdownButtonFormField<String>(initialValue:purchaseUnit,decoration:const InputDecoration(labelText:'Единица',border:OutlineInputBorder()),items:(base=='ml'?['ml','l']:base=='pcs'?['pcs']:['g','kg']).map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v)=>refresh(()=>purchaseUnit=v??purchaseUnit))),
        ]),
        const SizedBox(height:7),
        TextField(controller:supplier,decoration:const InputDecoration(labelText:'Поставщик',border:OutlineInputBorder())),
        const SizedBox(height:7),
        TextField(controller:priceSource,decoration:const InputDecoration(labelText:'Источник/номер прайса',border:OutlineInputBorder())),
        const SizedBox(height:14),
        const Align(alignment:Alignment.centerLeft,child:Text('Пищевая ценность на 100 г/мл',style:TextStyle(fontWeight:FontWeight.w700,color:dark))),
        const SizedBox(height:7),
        TextField(controller:kcal,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Калорийность, ккал',border:OutlineInputBorder())),
        const SizedBox(height:7),
        TextField(controller:protein,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Белки, г',border:OutlineInputBorder())),
        const SizedBox(height:7),
        TextField(controller:fat,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Жиры, г',border:OutlineInputBorder())),
        const SizedBox(height:7),
        TextField(controller:carbs,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Углеводы, г',border:OutlineInputBorder())),
        const SizedBox(height:7),
        TextField(controller:source,decoration:const InputDecoration(labelText:'Источник КБЖУ (этикетка/производитель)',border:OutlineInputBorder())),
        CheckboxListTile(contentPadding:EdgeInsets.zero,value:review,onChanged:(v)=>refresh(()=>review=v??true),title:const Text('Требует проверки',style:TextStyle(fontSize:13))),
        if(formError!=null)Text(formError!,style:const TextStyle(color:Colors.red)),
      ]))),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Отмена')),
        FilledButton(style:FilledButton.styleFrom(backgroundColor:brown),onPressed:() async {
          final n=name.text.trim();
          if(n.isEmpty){refresh(()=>formError='Укажите название');return;}
          double? parse(TextEditingController c)=>c.text.trim().isEmpty?null:double.tryParse(c.text.replaceAll(',','.'));
          final p=parse(price),q=parse(pack);
          if(price.text.trim().isNotEmpty&&(p==null||p<0||q==null||q<=0)){refresh(()=>formError='Проверьте цену и количество упаковки');return;}
          final macros=[kcal,protein,fat,carbs];
          if(macros.any((c)=>c.text.trim().isNotEmpty&&parse(c)==null)){refresh(()=>formError='Проверьте значения КБЖУ');return;}
          try{
            final payload={'name':n,'normalized_name':normalize(n),'base_unit':base,'calories_per_100':parse(kcal),'protein_per_100':parse(protein),'fat_per_100':parse(fat),'carbs_per_100':parse(carbs),'nutrition_source':source.text.trim().isEmpty?null:source.text.trim(),'needs_review':review,'updated_at':DateTime.now().toUtc().toIso8601String()};
            final id=row==null?(await db.from('ingredients').insert(payload).select('id').single())['id'].toString():row['id'].toString();
            if(row!=null)await db.from('ingredients').update(payload).eq('id',id);
            if(price.text.trim().isNotEmpty&&p!=null&&q!=null)await db.from('ingredient_prices').upsert({'ingredient_id':id,'purchase_price':p,'purchase_quantity':q,'purchase_unit':purchaseUnit,'updated_at':DateTime.now().toUtc().toIso8601String(),'updated_by':db.auth.currentUser?.id,'supplier_name':supplier.text.trim().isEmpty?null:supplier.text.trim(),'price_source':priceSource.text.trim().isEmpty?null:priceSource.text.trim()});
            if(ctx.mounted)Navigator.pop(ctx,true);
          }catch(e){refresh(()=>formError='Не удалось сохранить: '+e.toString());}
        },child:const Text('Сохранить')),
      ],
    )));
    for(final c in [name,price,pack,kcal,protein,fat,carbs,source,supplier,priceSource]){c.dispose();}
    if(saved==true)await load();
  }

  Future<void> showHistory(Map<String,dynamic> row) async {
    try {
      final data=await db.from('ingredient_price_history').select('supplier_name,package_label,purchase_quantity,purchase_unit,purchase_price,price_per_base_unit,price_valid_from,price_source,changed_at').eq('ingredient_id',row['id']).order('changed_at',ascending:false).limit(50);
      if(!mounted)return;
      await showModalBottomSheet<void>(context:context,isScrollControlled:true,backgroundColor:bg,builder:(ctx)=>SafeArea(child:Padding(padding:const EdgeInsets.all(18),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('История цен · '+row['name'].toString(),style:const TextStyle(fontSize:18,fontWeight:FontWeight.w700,color:dark)),
        const SizedBox(height:12),
        if((data as List).isEmpty)const Text('История пока пуста. Новые изменения будут записываться автоматически.'),
        SizedBox(height:360,child:ListView(shrinkWrap:true,children:data.map((e){final x=Map<String,dynamic>.from(e as Map);return ListTile(contentPadding:EdgeInsets.zero,title:Text(money(x['purchase_price'] as num?)+' за упаковку'),subtitle:Text((x['supplier_name']??'Поставщик не указан').toString()+' · '+x['purchase_quantity'].toString()+' '+x['purchase_unit'].toString()+' · '+(x['price_valid_from']??'').toString()),trailing:Text((x['changed_at']??'').toString().substring(0,10),style:const TextStyle(fontSize:11,color:muted)));}).toList())),
      ]))));
    } catch(e) {
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('История цен доступна после применения миграции: '+e.toString())));
    }
  }

  @override
  Widget build(BuildContext context){
    final filtered=rows.where((r)=>r['name'].toString().toLowerCase().contains(search.text.toLowerCase())).toList();
    return Scaffold(
      backgroundColor:bg,
      appBar:AppBar(backgroundColor:bg,elevation:0,title:const Text('Справочник сырья и цен',style:TextStyle(color:dark,fontWeight:FontWeight.w700)),iconTheme:const IconThemeData(color:brown),actions:[IconButton(onPressed:load,icon:const Icon(Icons.refresh))]),
      floatingActionButton:FloatingActionButton.extended(backgroundColor:brown,foregroundColor:Colors.white,onPressed:()=>edit(),icon:const Icon(Icons.add),label:const Text('Добавить сырьё')),
      body:Column(children:[
        Padding(padding:const EdgeInsets.fromLTRB(16,8,16,12),child:TextField(controller:search,onChanged:(_)=>setState((){}),decoration:InputDecoration(prefixIcon:const Icon(Icons.search),hintText:'Поиск ингредиента',filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:BorderSide.none)))),
        Expanded(child:busy?const Center(child:CircularProgressIndicator(color:brown)):error!=null?Center(child:Padding(padding:const EdgeInsets.all(24),child:Text(error!,textAlign:TextAlign.center))):filtered.isEmpty?const Center(child:Text('Справочник пуст. Добавьте первое сырьё.')):RefreshIndicator(onRefresh:load,child:ListView.builder(padding:const EdgeInsets.fromLTRB(16,0,16,90),itemCount:filtered.length,itemBuilder:(ctx,i){
          final r=filtered[i];final prices=r['ingredient_prices'] as List? ?? [];final pr=prices.isEmpty?null:Map<String,dynamic>.from(prices.first as Map);final per=pr?['price_per_base_unit'] as num?;final unit=r['base_unit']=='ml'?'мл':r['base_unit']=='pcs'?'шт':'г';final priceKg=r['base_unit']=='g'&&per!=null?per*1000:null;
          final priceText=priceKg==null?(per==null?'не задана':money(per)+'/'+unit):money(priceKg)+'/кг';
          final supplierText=pr?['supplier_name']?.toString()??'';
          final nutritionText=r['calories_per_100']==null?'нет данных':'заполнено';
          return Card(color:Colors.white,elevation:0,margin:const EdgeInsets.only(bottom:9),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15),side:const BorderSide(color:Color(0xFFEADFD5))),child:ListTile(onTap:()=>edit(r),title:Text(r['name'].toString(),style:const TextStyle(color:dark,fontWeight:FontWeight.w700)),subtitle:Padding(padding:const EdgeInsets.only(top:5),child:Text('Цена: '+priceText+' · КБЖУ: '+nutritionText+(supplierText.isEmpty?'':' · '+supplierText)+(r['needs_review']==true?' · проверить':''),style:const TextStyle(color:muted,fontSize:12))),trailing:IconButton(tooltip:'История цен',onPressed:()=>showHistory(r),icon:const Icon(Icons.history,color:brown))));
        }))),
      ]),
    );
  }
}
