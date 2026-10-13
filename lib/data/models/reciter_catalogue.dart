// GENERATED FILE — do not edit by hand.
//
// Produced by `tool/build_reciters.py`, which probes the live CDN with a
// real HTTP Range request against
//   https://cdn.islamic.network/quran/audio-surah/128/{id}/{surah}.mp3
// for surahs [1, 9, 36, 78, 114] and keeps only editions answering 200/206 every time.
// A 206 also proves Range support, which is what makes seeking work.
//
// 144 reciters verified. Excluded because the CDN answers 403 for
// surah-level audio (they remain ayah-by-ayah only):
//   ar.abdulbasitmurattal-surah, ar.abdullahbasfar-surah, ar.abdulsamad, ar.abdurrahmaansudais, ar.ahmedajamy, ar.alafasy-2, ar.alafasy-surah, ar.aymanswoaid, ar.hanirifai, ar.hudhaify, ar.hudhaify-2, ar.husary, ar.husary-2, ar.husarymujawwad, ar.husarymujawwad-2, ar.ibrahimakhbar, ar.mahermuaiqly, ar.mahermuaiqly-2, ar.minshawi, ar.minshawi-2, ar.minshawimujawwad, ar.muhammadayyoub, ar.muhammadayyoub-2, ar.muhammadjibreel …
//
// Re-run the generator to refresh this list; never hand-edit it.

import 'reciter.dart';

const List<QuranReciter> kVerifiedReciters = <QuranReciter>[
  QuranReciter(
    id: 'ar.alafasy',
    arabicName: 'مشاري راشد العفاسي',
    englishName: 'Mishary Rashid Alafasy',
  ),
  QuranReciter(
    id: 'ar.abdulbasitmurattal',
    arabicName: 'عبد الباسط عبد الصمد (مرتّل)',
    englishName: 'Abdul Basit (Murattal)',
  ),
  QuranReciter(
    id: 'ar.abdulbasitmujawwad',
    arabicName: 'عبد الباسط عبد الصمد (مجوّد)',
    englishName: 'Abdul Basit (Mujawwad)',
  ),
  QuranReciter(
    id: 'ar.muhammadsiddiqalminshawimujawwad',
    arabicName: 'محمد صديق المنشاوي (مجوّد)',
    englishName: 'Muhammad Siddiq al-Minshawi',
  ),
  QuranReciter(
    id: 'ar.saudalshuraim',
    arabicName: 'سعود الشريم',
    englishName: 'Saud ash-Shuraim',
  ),
  QuranReciter(
    id: 'ar.aliabdurrahmanalhuthaify',
    arabicName: 'علي بن عبد الرحمن الحذيفي',
    englishName: 'Ali Abdur-Rahman al-Huthaify',
  ),
  QuranReciter(
    id: 'ar.abdullahawadaljuhani',
    arabicName: 'عبد الله عواد الجهني',
    englishName: 'Abdullah Awad al-Juhani',
  ),
  QuranReciter(
    id: 'ar.yasseraldossari',
    arabicName: 'ياسر الدوسري',
    englishName: 'Yasser ad-Dossari',
  ),
  QuranReciter(
    id: 'ar.faresabbad',
    arabicName: 'فارس عباد',
    englishName: 'Fares Abbad',
  ),
  QuranReciter(
    id: 'ar.nasseralqatami',
    arabicName: 'ناصر القطامي',
    englishName: 'Nasser al-Qatami',
  ),
  QuranReciter(
    id: 'ar.muhammadayyub',
    arabicName: 'محمد أيوب',
    englishName: 'Muhammad Ayyub',
  ),
  QuranReciter(
    id: 'ar.ahmedalajmi',
    arabicName: 'أحمد بن علي العجمي',
    englishName: 'Ahmed ibn Ali al-Ajamy',
  ),
  QuranReciter(
    id: 'ar.haniarrifai',
    arabicName: 'هاني الرفاعي',
    englishName: 'Hani ar-Rifai',
  ),
  QuranReciter(
    id: 'ar.mohamedtablawi',
    arabicName: 'محمد محمود الطبلاوي',
    englishName: 'Mohamed at-Tablawi',
  ),
  QuranReciter(
    id: 'ar.mustafaismail',
    arabicName: 'مصطفى إسماعيل',
    englishName: 'Mustafa Ismail',
  ),
  QuranReciter(
    id: 'ar.muhammadalmehysni',
    arabicName: 'محمد المحيسني',
    englishName: 'Muhammad al-Mehysni',
  ),
  QuranReciter(
    id: 'ar.mahmoudalialbanna',
    arabicName: 'محمود علي البنّا',
    englishName: 'Mahmoud Ali al-Banna',
  ),
  QuranReciter(
    id: 'ar.abdullahbasfar',
    arabicName: 'عبد الله بصفر',
    englishName: 'Abdullah Basfar',
  ),
  QuranReciter(
    id: 'ar.abdulazizazzahrani',
    arabicName: 'عبد العزيز الزهراني',
    englishName: 'Abdul Aziz az-Zahrani',
  ),
  QuranReciter(
    id: 'ar.abdulbariaththubaity',
    arabicName: 'عبد الباري الثبيتي',
    englishName: 'Abdul Bari ath-Thubaity',
  ),
  QuranReciter(
    id: 'ar.abdulbarimohammed',
    arabicName: 'عبد الباري محمد',
    englishName: 'Abdul Bari Mohammed',
  ),
  QuranReciter(
    id: 'ar.abdulkareemalhazmi',
    arabicName: 'عبد الكريم الحازمي',
    englishName: 'Abdul Kareem al-Hazmi',
  ),
  QuranReciter(
    id: 'ar.abdullahalmatrood',
    arabicName: 'عبد الله المطرود',
    englishName: 'Abdullah al-Matrood',
  ),
  QuranReciter(
    id: 'ar.abdullahkhayat',
    arabicName: 'عبد الله خياط',
    englishName: 'Abdullah Khayat',
  ),
  QuranReciter(
    id: 'ar.abdullahkhulaifi',
    arabicName: 'عبد الله الخليفي',
    englishName: 'Abdullah al-Khulaifi',
  ),
  QuranReciter(
    id: 'ar.abdulmohsenalharthy',
    arabicName: 'عبد المحسن الحارثي',
    englishName: 'Abdul Mohsen al-Harthy',
  ),
  QuranReciter(
    id: 'ar.abdulmunimabdulmubdi',
    arabicName: 'عبد المنعم عبد المبدئ',
    englishName: 'Abdul Munim Abdul Mubdi',
  ),
  QuranReciter(
    id: 'ar.abdulwadoodhaneef',
    arabicName: 'عبد الودود حنيف',
    englishName: 'Abdul Wadood Haneef',
  ),
  QuranReciter(
    id: 'ar.abdurrasheedsufiabialhaarithanalkasaaee',
    arabicName: 'عبد الرشيد صوفي (أبو الحارث عن الكسائي)',
    englishName: 'Abdur-Rasheed Sufi (Abul-Harith from al-Kisa\'i)',
  ),
  QuranReciter(
    id: 'ar.abdurrasheedsufiaddoorianabiamr',
    arabicName: 'عبد الرشيد صوفي (الدوري عن أبي عمرو)',
    englishName: 'Abdur-Rasheed Sufi (ad-Doori from Abu Amr)',
  ),
  QuranReciter(
    id: 'ar.abdurrasheedsufishubahanasim',
    arabicName: 'عبد الرشيد صوفي (شعبة عن عاصم)',
    englishName: 'Abdur-Rasheed Sufi (Shu\'bah from Asim)',
  ),
  QuranReciter(
    id: 'ar.abdurrasheedsufisoosi',
    arabicName: 'عبد الرشيد صوفي (السوسي)',
    englishName: 'Abdur-Rasheed Sufi (as-Soosi)',
  ),
  QuranReciter(
    id: 'ar.abuabdullahmuniraltounsi',
    arabicName: 'أبو عبد الله منير التونسي',
    englishName: 'Abu Abdullah Munir at-Tounsi',
  ),
  QuranReciter(
    id: 'ar.abubakraldhabi',
    arabicName: 'أبو بكر الذهبي',
    englishName: 'Abu Bakr adh-Dhabi',
  ),
  QuranReciter(
    id: 'ar.adilkalbani',
    arabicName: 'عادل الكلباني',
    englishName: 'Adil al-Kalbani',
  ),
  QuranReciter(
    id: 'ar.ahmadalhawashy',
    arabicName: 'أحمد الحواشي',
    englishName: 'Ahmad al-Hawashy',
  ),
  QuranReciter(
    id: 'ar.ahmadkhaderaltarabulsi',
    arabicName: 'أحمد خضر الطرابلسي',
    englishName: 'Ahmad Khader at-Tarabulsi',
  ),
  QuranReciter(
    id: 'ar.ahmadsulaiman',
    arabicName: 'أحمد سليمان',
    englishName: 'Ahmad Sulaiman',
  ),
  QuranReciter(
    id: 'ar.ahmedalhammad',
    arabicName: 'أحمد الحماد',
    englishName: 'Ahmed al-Hammad',
  ),
  QuranReciter(
    id: 'ar.ahmedalmisbahi',
    arabicName: 'أحمد المصباحي',
    englishName: 'Ahmed al-Misbahi',
  ),
  QuranReciter(
    id: 'ar.ahmedamir',
    arabicName: 'أحمد عامر',
    englishName: 'Ahmed Amir',
  ),
  QuranReciter(
    id: 'ar.ahmedmohamedsalama',
    arabicName: 'أحمد محمد سلامة',
    englishName: 'Ahmed Mohamed Salama',
  ),
  QuranReciter(
    id: 'ar.ahmedsaber',
    arabicName: 'أحمد صابر',
    englishName: 'Ahmed Saber',
  ),
  QuranReciter(
    id: 'ar.alashryomran',
    arabicName: 'العشري عمران',
    englishName: 'al-Ashry Omran',
  ),
  QuranReciter(
    id: 'ar.alfatehmuhammadzubair',
    arabicName: 'الفاتح محمد الزبير',
    englishName: 'al-Fateh Muhammad Zubair',
  ),
  QuranReciter(
    id: 'ar.alhusaynialazazi',
    arabicName: 'الحسيني العزازي',
    englishName: 'al-Husayni al-Azazi',
  ),
  QuranReciter(
    id: 'ar.alhusaynialazazichildren',
    arabicName: 'الحسيني العزازي (مع الأطفال)',
    englishName: 'al-Husayni al-Azazi (with children)',
  ),
  QuranReciter(
    id: 'ar.aliabdurrahmanalhuthaifyqaloon',
    arabicName: 'علي عبد الرحمن الحذيفي (قالون)',
    englishName: 'Ali Abdur-Rahman al-Huthaify (Qaloon)',
  ),
  QuranReciter(
    id: 'ar.alihajjajsouissi',
    arabicName: 'علي حجاج السويسي',
    englishName: 'Ali Hajjaj Souissi',
  ),
  QuranReciter(
    id: 'ar.alzainmohamedahmed',
    arabicName: 'الزين محمد أحمد',
    englishName: 'al-Zain Mohamed Ahmed',
  ),
  QuranReciter(
    id: 'ar.aymanswed',
    arabicName: 'أيمن سويد',
    englishName: 'Ayman Swed',
  ),
  QuranReciter(
    id: 'ar.azizalili',
    arabicName: 'عزيز عليلي',
    englishName: 'Aziz Alili',
  ),
  QuranReciter(
    id: 'ar.basselabdulrahmanraoui',
    arabicName: 'باسل عبد الرحمن الراوي',
    englishName: 'Bassel Abdul-Rahman ar-Raoui',
  ),
  QuranReciter(
    id: 'ar.benkirane',
    arabicName: 'بنكيران',
    englishName: 'Benkirane',
  ),
  QuranReciter(
    id: 'ar.darwishfarajdarwishalattar',
    arabicName: 'درويش فرج درويش العطار',
    englishName: 'Darwish Faraj Darwish al-Attar',
  ),
  QuranReciter(
    id: 'ar.emadalmansary',
    arabicName: 'عماد المنصري',
    englishName: 'Emad al-Mansary',
  ),
  QuranReciter(
    id: 'ar.ezzatsabri',
    arabicName: 'عزت صبري',
    englishName: 'Ezzat Sabri',
  ),
  QuranReciter(
    id: 'ar.fouadalkhamiri',
    arabicName: 'فؤاد الخامري',
    englishName: 'Fouad al-Khamiri',
  ),
  QuranReciter(
    id: 'ar.hamadsinan',
    arabicName: 'حمد سنان',
    englishName: 'Hamad Sinan',
  ),
  QuranReciter(
    id: 'ar.hamdyalsayedtolbasaad',
    arabicName: 'حمدي السيد طلبة سعد',
    englishName: 'Hamdy al-Sayed Tolba Saad',
  ),
  QuranReciter(
    id: 'ar.hasanhashem',
    arabicName: 'حسن هاشم',
    englishName: 'Hasan Hashem',
  ),
  QuranReciter(
    id: 'ar.hassansaleh',
    arabicName: 'حسن صالح',
    englishName: 'Hassan Saleh',
  ),
  QuranReciter(
    id: 'ar.hatemfarid',
    arabicName: 'حاتم فريد',
    englishName: 'Hatem Farid',
  ),
  QuranReciter(
    id: 'ar.ibrahimalakhdar',
    arabicName: 'إبراهيم الأخضر',
    englishName: 'Ibrahim al-Akhdar',
  ),
  QuranReciter(
    id: 'ar.ibrahimaldossari',
    arabicName: 'إبراهيم الدوسري',
    englishName: 'Ibrahim ad-Dossari',
  ),
  QuranReciter(
    id: 'ar.ibrahimaljormy',
    arabicName: 'إبراهيم الجرمي',
    englishName: 'Ibrahim al-Jormy',
  ),
  QuranReciter(
    id: 'ar.ilhantok',
    arabicName: 'إلهان توك',
    englishName: 'Ilhan Tok',
  ),
  QuranReciter(
    id: 'ar.imadzuhairhafez',
    arabicName: 'عماد زهير حافظ',
    englishName: 'Imad Zuhair Hafez',
  ),
  QuranReciter(
    id: 'ar.jamaanalosaimi',
    arabicName: 'جمعان العصيمي',
    englishName: 'Jamaan al-Osaimi',
  ),
  QuranReciter(
    id: 'ar.jamalshakerabdullah',
    arabicName: 'جمال شاكر عبد الله',
    englishName: 'Jamal Shaker Abdullah',
  ),
  QuranReciter(
    id: 'ar.jazzaalswaileh',
    arabicName: 'جزاع الصويلح',
    englishName: 'Jazza al-Swaileh',
  ),
  QuranReciter(
    id: 'ar.kamel',
    arabicName: 'كامل',
    englishName: 'Kamel',
  ),
  QuranReciter(
    id: 'ar.khaledalqahtani',
    arabicName: 'خالد القحطاني',
    englishName: 'Khaled al-Qahtani',
  ),
  QuranReciter(
    id: 'ar.khaledbarakat',
    arabicName: 'خالد بركات',
    englishName: 'Khaled Barakat',
  ),
  QuranReciter(
    id: 'ar.khalidabdulkafi',
    arabicName: 'خالد عبد الكافي',
    englishName: 'Khalid Abdul-Kafi',
  ),
  QuranReciter(
    id: 'ar.khalidaljalil',
    arabicName: 'خالد الجليل',
    englishName: 'Khalid al-Jalil',
  ),
  QuranReciter(
    id: 'ar.khalidalmohanna',
    arabicName: 'خالد المهنا',
    englishName: 'Khalid al-Mohanna',
  ),
  QuranReciter(
    id: 'ar.khalifaaltunaiji',
    arabicName: 'خليفة الطنيجي',
    englishName: 'Khalifa at-Tunaiji',
  ),
  QuranReciter(
    id: 'ar.laayounelkouchi',
    arabicName: 'العيون الكوشي',
    englishName: 'Laayoun el-Kouchi',
  ),
  QuranReciter(
    id: 'ar.mahershakhashiro',
    arabicName: 'ماهر شخاشيرو',
    englishName: 'Maher Shakhashiro',
  ),
  QuranReciter(
    id: 'ar.mahmoodalrifai',
    arabicName: 'محمود الرفاعي',
    englishName: 'Mahmood al-Rifai',
  ),
  QuranReciter(
    id: 'ar.mahmoudelsheimy',
    arabicName: 'محمود الشيمي',
    englishName: 'Mahmoud el-Sheimy',
  ),
  QuranReciter(
    id: 'ar.mahmoudsaaddarouich',
    arabicName: 'محمود سعد درويش',
    englishName: 'Mahmoud Saad Darouich',
  ),
  QuranReciter(
    id: 'ar.mahmoudsayedeltayeb',
    arabicName: 'محمود سيد الطيب',
    englishName: 'Mahmoud Sayed el-Tayeb',
  ),
  QuranReciter(
    id: 'ar.moeedhalharthi',
    arabicName: 'معيض الحارثي',
    englishName: 'Moeedh al-Harthi',
  ),
  QuranReciter(
    id: 'ar.mohamedabdelaziz',
    arabicName: 'محمد عبد العزيز',
    englishName: 'Mohamed Abdel-Aziz',
  ),
  QuranReciter(
    id: 'ar.mohamedabdelhakimsaadalabdullah',
    arabicName: 'محمد عبد الحكيم سعد العبد الله',
    englishName: 'Mohamed Abdel-Hakim Saad al-Abdullah',
  ),
  QuranReciter(
    id: 'ar.mohamedaljaberyalheyani',
    arabicName: 'محمد الجابري الحياني',
    englishName: 'Mohamed al-Jabery al-Heyani',
  ),
  QuranReciter(
    id: 'ar.mohamedelkantaoui',
    arabicName: 'محمد القنطاوي',
    englishName: 'Mohamed el-Kantaoui',
  ),
  QuranReciter(
    id: 'ar.mohamedhassan',
    arabicName: 'محمد حسان',
    englishName: 'Mohamed Hassan',
  ),
  QuranReciter(
    id: 'ar.mohamedmaabad',
    arabicName: 'محمد معبد',
    englishName: 'Mohamed Maabad',
  ),
  QuranReciter(
    id: 'ar.mohamedosmankhan',
    arabicName: 'محمد عثمان خان',
    englishName: 'Mohamed Osman Khan',
  ),
  QuranReciter(
    id: 'ar.mohamedshaabanabuqarn',
    arabicName: 'محمد شعبان أبو قرن',
    englishName: 'Mohamed Shaaban Abu Qarn',
  ),
  QuranReciter(
    id: 'ar.mohammadismaeelalmuqaddim',
    arabicName: 'محمد إسماعيل المقدم',
    englishName: 'Mohammad Ismaeel al-Muqaddim',
  ),
  QuranReciter(
    id: 'ar.mohammadrachadalshareef',
    arabicName: 'محمد رشاد الشريف',
    englishName: 'Mohammad Rachad al-Shareef',
  ),
  QuranReciter(
    id: 'ar.mohammedbinsalehabuzaid',
    arabicName: 'محمد بن صالح أبو زيد',
    englishName: 'Mohammed bin Saleh Abu Zaid',
  ),
  QuranReciter(
    id: 'ar.muftahalsaltany',
    arabicName: 'مفتاح السلطني',
    englishName: 'Muftah al-Saltany',
  ),
  QuranReciter(
    id: 'ar.muhammadabdulkareem',
    arabicName: 'محمد عبد الكريم',
    englishName: 'Muhammad Abdul-Kareem',
  ),
  QuranReciter(
    id: 'ar.muhammadalaalimaldokali',
    arabicName: 'محمد العالم الدوكالي',
    englishName: 'Muhammad al-Aalim ad-Dokali',
  ),
  QuranReciter(
    id: 'ar.muhammadalluhaidan',
    arabicName: 'محمد اللحيدان',
    englishName: 'Muhammad al-Luhaidan',
  ),
  QuranReciter(
    id: 'ar.muhammadalsubayyil',
    arabicName: 'محمد السبيل',
    englishName: 'Muhammad as-Subayyil',
  ),
  QuranReciter(
    id: 'ar.muhammadanwarshahat',
    arabicName: 'محمد أنور شحات',
    englishName: 'Muhammad Anwar Shahat',
  ),
  QuranReciter(
    id: 'ar.muhammadsalehalimshah',
    arabicName: 'محمد صالح عالم شاه',
    englishName: 'Muhammad Saleh Alim Shah',
  ),
  QuranReciter(
    id: 'ar.muhammadsulaimanpatel',
    arabicName: 'محمد سليمان باتل',
    englishName: 'Muhammad Sulaiman Patel',
  ),
  QuranReciter(
    id: 'ar.musabilal',
    arabicName: 'موسى بلال',
    englishName: 'Musa Bilal',
  ),
  QuranReciter(
    id: 'ar.mustafaallahouni',
    arabicName: 'مصطفى اللاهوني',
    englishName: 'Mustafa al-Lahouni',
  ),
  QuranReciter(
    id: 'ar.mustafaraadalazzawi',
    arabicName: 'مصطفى رعد العزاوي',
    englishName: 'Mustafa Raad al-Azzawi',
  ),
  QuranReciter(
    id: 'ar.mustaphagharbi',
    arabicName: 'مصطفى غربي',
    englishName: 'Mustapha Gharbi',
  ),
  QuranReciter(
    id: 'ar.nabilarrifai',
    arabicName: 'نبيل الرفاعي',
    englishName: 'Nabil ar-Rifai',
  ),
  QuranReciter(
    id: 'ar.neamahalhassan',
    arabicName: 'نعمة الحسن',
    englishName: 'Neamah al-Hassan',
  ),
  QuranReciter(
    id: 'ar.obeikan',
    arabicName: 'العبيكان',
    englishName: 'al-Obeikan',
  ),
  QuranReciter(
    id: 'ar.omaralkazabri',
    arabicName: 'عمر القزابري',
    englishName: 'Omar al-Kazabri',
  ),
  QuranReciter(
    id: 'ar.osamabinalialghanim',
    arabicName: 'أسامة بن علي الغانم',
    englishName: 'Osama bin Ali al-Ghanim',
  ),
  QuranReciter(
    id: 'ar.rachidbelalia',
    arabicName: 'رشيد بلعالية',
    englishName: 'Rachid Belalia',
  ),
  QuranReciter(
    id: 'ar.saberabdulhakam',
    arabicName: 'صابر عبد الحكم',
    englishName: 'Saber Abdul-Hakam',
  ),
  QuranReciter(
    id: 'ar.sadaqatali',
    arabicName: 'صداقت علي',
    englishName: 'Sadaqat Ali',
  ),
  QuranReciter(
    id: 'ar.sahlyasin',
    arabicName: 'سهل ياسين',
    englishName: 'Sahl Yasin',
  ),
  QuranReciter(
    id: 'ar.saidalshaalan',
    arabicName: 'سعيد الشعلان',
    englishName: 'Said ash-Shaalan',
  ),
  QuranReciter(
    id: 'ar.salahalbudair',
    arabicName: 'صلاح البدير',
    englishName: 'Salah al-Budair',
  ),
  QuranReciter(
    id: 'ar.salahalhashem',
    arabicName: 'صلاح الهاشم',
    englishName: 'Salah al-Hashem',
  ),
  QuranReciter(
    id: 'ar.salahbaothman',
    arabicName: 'صلاح باعثمان',
    englishName: 'Salah Ba-Othman',
  ),
  QuranReciter(
    id: 'ar.samirbelaachya',
    arabicName: 'سمير بلعشية',
    englishName: 'Samir Belaachya',
  ),
  QuranReciter(
    id: 'ar.sayedramadan',
    arabicName: 'سيد رمضان',
    englishName: 'Sayed Ramadan',
  ),
  QuranReciter(
    id: 'ar.shahriarparhizgar',
    arabicName: 'شهريار پرهيزگار',
    englishName: 'Shahriar Parhizgar',
  ),
  QuranReciter(
    id: 'ar.sudaisshuraymnaeemsultan',
    arabicName: 'السديس والشريم (مع ترجمة نعيم سلطان)',
    englishName: 'Sudais & Shuraym (with Naeem Sultan translation)',
  ),
  QuranReciter(
    id: 'ar.tamerislam',
    arabicName: 'تامر إسلام',
    englishName: 'Tamer Islam',
  ),
  QuranReciter(
    id: 'ar.tareqabdulganidaawob',
    arabicName: 'طارق عبد الغني دعوب',
    englishName: 'Tareq Abdul-Gani Daawob',
  ),
  QuranReciter(
    id: 'ar.tawfeeqassayegh',
    arabicName: 'توفيق الصايغ',
    englishName: 'Tawfeeq as-Sayegh',
  ),
  QuranReciter(
    id: 'ar.turkiebeidalmarri',
    arabicName: 'تركي عبيد المري',
    englishName: 'Turki Ebeid al-Marri',
  ),
  QuranReciter(
    id: 'ar.waeldesouky',
    arabicName: 'وائل الدسوقي',
    englishName: 'Wael ad-Desouky',
  ),
  QuranReciter(
    id: 'ar.waelradwanqureshi',
    arabicName: 'وائل رضوان قريشي',
    englishName: 'Wael Radwan Qureshi',
  ),
  QuranReciter(
    id: 'ar.waleedidreesalmaneese',
    arabicName: 'وليد إدريس المنيسي',
    englishName: 'Waleed Idrees al-Maneese',
  ),
  QuranReciter(
    id: 'ar.waleednaehi',
    arabicName: 'وليد الناهي',
    englishName: 'Waleed an-Naehi',
  ),
  QuranReciter(
    id: 'ar.waleedsamiraliabdulmajidsorour',
    arabicName: 'وليد سمير علي عبد المجيد سرور',
    englishName: 'Waleed Samir Ali Abdul-Majid Sorour',
  ),
  QuranReciter(
    id: 'ar.walidalshatti',
    arabicName: 'وليد الشطي',
    englishName: 'Walid ash-Shatti',
  ),
  QuranReciter(
    id: 'ar.walidfathibashta',
    arabicName: 'وليد فتحي بشتة',
    englishName: 'Walid Fathi Bashta',
  ),
  QuranReciter(
    id: 'ar.yahyahawwa',
    arabicName: 'يحيى حوى',
    englishName: 'Yahya Hawwa',
  ),
  QuranReciter(
    id: 'ar.yassenaljazairi',
    arabicName: 'ياسين الجزائري',
    englishName: 'Yassen al-Jazairi',
  ),
  QuranReciter(
    id: 'ar.yasseralmazroyee',
    arabicName: 'ياسر المزروعي',
    englishName: 'Yasser al-Mazroyee',
  ),
  QuranReciter(
    id: 'ar.yasserqureshi',
    arabicName: 'ياسر قريشي',
    englishName: 'Yasser Qureshi',
  ),
  QuranReciter(
    id: 'ar.yassersalama',
    arabicName: 'ياسر سلامة',
    englishName: 'Yasser Salama',
  ),
  QuranReciter(
    id: 'ar.yassersarhaneldeeb',
    arabicName: 'ياسر سرحان الديب',
    englishName: 'Yasser Sarhan el-Deeb',
  ),
  QuranReciter(
    id: 'ar.yousufalshoaey',
    arabicName: 'يوسف الشويعي',
    englishName: 'Yousuf ash-Shoaey',
  ),
  QuranReciter(
    id: 'ar.yousufbinnoahahmad',
    arabicName: 'يوسف بن نوح أحمد',
    englishName: 'Yousuf bin Noah Ahmad',
  ),
];
