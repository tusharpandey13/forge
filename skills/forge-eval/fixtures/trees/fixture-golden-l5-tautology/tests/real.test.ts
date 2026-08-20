describe('real tests', () => {
  it('checks variable', () => {
    const result = computeValue(42);
    expect(result).toBe(42);
  });
  it('verifies state', () => {
    const state = getState();
    expect(state.isValid).toBe(true);
  });
});
