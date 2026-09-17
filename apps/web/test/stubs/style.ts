// Vite can import a stylesheet as a module; Node cannot. Jest maps every .css
// import to this file so that importing a component does not crash. The first
// test that needs it is app/root.test.tsx, because root.tsx imports app.css.
export default {};
