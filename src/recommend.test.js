const { recommend } = require('../');

describe('Test for input values', () => {
  test('forest type today is required', () => {
    expect(() => recommend()).toThrowError('forestTypeToday is required');
  });

  test('at least 1 projected forestType is required', () => {
    expect(() => recommend('60', [])).toThrowError(
      `at least 1 projected forestType is required`,
    );
  });

  test('invalid forestType', () => {
    expect(() =>
      recommend('fooBar', [{ forestType: '8b' }, { forestType: '7b' }]),
    ).toThrowError('fooBar is not valid');
  });

  test('invalid forestType in projections', () => {
    expect(() =>
      recommend('60', [{ forestType: 'fooBar1' }, { forestType: 'fooBar2' }]),
    ).toThrowError('fooBar1 is not valid');
  });

  test('invalid type for future flag', () => {
    expect(() =>
      recommend('60', [{ forestType: '8b' }, { forestType: '7b' }], 'fooBar'),
    ).toThrowError(`expected boolean type for future flag`);
  });
});

describe('Test for output values', () => {
  test('valid recommendations for single projection', () => {
    expect(recommend('19f', [{ forestType: '8b' }], true)).toStrictEqual([
      [100, 165000, 302800],
      [],
      [],
      [],
      [402300, 60400, 317500, 363700, 330600],
      [],
      [
        700,
        800,
        97200,
        174200,
        213300,
        227200,
        306100,
        328400,
        335900,
        336100,
        413600,
        421400,
        432800,
        336200,
      ],
      [],
      [25300, 402200],
      [],
    ]);
  });
  test('valid recommendations for multiple projection', () => {
    expect(
      recommend('19f', [{ forestType: '8b' }, { forestType: '7b' }], true),
    ).toStrictEqual([
      [100, 165000],
      [302800],
      [],
      [336100],
      [402300, 60400, 317500, 363700, 330600],
      [302800],
      [
        700,
        800,
        97200,
        174200,
        213300,
        227200,
        306100,
        328400,
        335900,
        413600,
        421400,
        432800,
        336200,
      ],
      [336100, 25200, 96900, 329700, 346500],
      [25300, 402200],
      [],
    ]);
  });
});
