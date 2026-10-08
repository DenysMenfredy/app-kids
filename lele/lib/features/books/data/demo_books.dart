import '../domain/book.dart';

/// Catalog fixture for demo mode. Premium text is never bundled in the app.
const demoBooks = [
  Book(
    id: 'sapo',
    title: 'O Sapo e a Lua',
    description: 'Uma noite de pulos e descobertas na lagoa.',
    coverKey: 'frog',
    pageCount: 5,
    access: BookAccess.free,
    contentVersion: 1,
    order: 0,
  ),
  Book(
    id: 'vogais',
    title: 'A Festa das Vogais',
    description: 'A, E, I, O e U têm uma surpresa para você.',
    coverKey: 'vowels',
    pageCount: 5,
    access: BookAccess.free,
    contentVersion: 1,
    order: 1,
  ),
  Book(
    id: 'bicho',
    title: 'Bicho de Letra',
    description: 'Cada bichinho descobre a letra do seu nome.',
    coverKey: 'cat',
    pageCount: 4,
    access: BookAccess.premium,
    contentVersion: 1,
    order: 2,
  ),
  Book(
    id: 'trem',
    title: 'O Trem das Sílabas',
    description: 'Embarque para juntar pedacinhos de palavras.',
    coverKey: 'train',
    pageCount: 5,
    access: BookAccess.premium,
    contentVersion: 1,
    order: 3,
  ),
  Book(
    id: 'rimas',
    title: 'Rimas no Jardim',
    description: 'Ouça as palavras que combinam no final.',
    coverKey: 'flowers',
    pageCount: 4,
    access: BookAccess.premium,
    contentVersion: 1,
    order: 4,
  ),
  Book(
    id: 'historia',
    title: 'Minha Primeira História',
    description: 'Uma aventura pequena pode virar uma grande história.',
    coverKey: 'book',
    pageCount: 4,
    access: BookAccess.premium,
    contentVersion: 1,
    order: 5,
  ),
];

const demoBookPages = <String, List<BookPage>>{
  'sapo': [
    BookPage(
      id: 'p1',
      text: 'Na beira da lagoa, o sapo Sabi viu uma luz redonda no céu.',
      illustration: 'pond',
    ),
    BookPage(
      id: 'p2',
      text: '— Olá, Lua! — disse Sabi. A Lua brilhou bem alto.',
      illustration: 'moon',
    ),
    BookPage(
      id: 'p3',
      text:
          'Sabi pulou para tocar a luz. Plim! Caiu na água e fez muitas ondas.',
      illustration: 'frog',
    ),
    BookPage(
      id: 'p4',
      text: 'Quando a água ficou calma, a Lua apareceu de novo na lagoa.',
      illustration: 'pond',
    ),
    BookPage(
      id: 'p5',
      text: 'Sabi sorriu. — Você fica no céu, e eu fico aqui. Boa noite, Lua!',
      illustration: 'moon',
    ),
  ],
  'vogais': [
    BookPage(
      id: 'p1',
      text: 'A levou uma abelha para a festa. A abelha voou: zum, zum, zum!',
      illustration: 'letters',
    ),
    BookPage(
      id: 'p2',
      text: 'E levou uma estrela de papel. Ela brilhou na parede da sala.',
      illustration: 'moon',
    ),
    BookPage(
      id: 'p3',
      text: 'I levou o desenho de uma ilha. Na ilha havia sol e areia.',
      illustration: 'sun',
    ),
    BookPage(
      id: 'p4',
      text: 'O levou um ovo pintado. Que ovo redondo e colorido!',
      illustration: 'party',
    ),
    BookPage(
      id: 'p5',
      text: 'U levou uvas para todos. As cinco amigas cantaram: A, E, I, O, U!',
      illustration: 'vowels',
    ),
  ],
};
