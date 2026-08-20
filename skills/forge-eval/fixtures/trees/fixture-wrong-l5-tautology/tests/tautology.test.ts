describe('bad tests', () => {
  it('is always true', () => {
    expect(true).toBe(true);
  });
  it('another tautology', () => {
    expect(false).toBe(false);
  });
});
