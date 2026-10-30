import * as originalViews from './originalViews.js';
window.jbcOriginalViews=originalViews;
if(window.jbcVerifiedAuth && /^(shipments|loads|shipment-new|shipment\/)/.test(location.hash.slice(1))) window.render();
