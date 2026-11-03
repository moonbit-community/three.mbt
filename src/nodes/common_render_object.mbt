// renderers/common/RenderObject.js. `getMaterialCacheKey` enumerates the material's
// keys as upstream's `getKeys` does (own keys in construction order, then prototype
// getters); MoonBit materials have no such reflection, so the key order of each node
// material class is recorded from upstream r187 below, and values are read by name from
// the class (`NodeMaterialClass::get_property`), the `NodeMaterial` slots and the core
// `Material` fields.

///|
let _render_object_id : Ref[Int32] = Ref(0)

///|
let _render_object_infinity : Double = 1.0 / 0.0

///|
/// JS string order (UTF-16 code units), as `Array.prototype.sort()` uses.
extern "js" fn render_object_js_compare(a : String, b : String) -> Int32 = "(a, b) => a < b ? -1 : ( a > b ? 1 : 0 )"

///|
extern "js" fn render_object_js_string(x : Double) -> String = "(x) => String(x)"

///|
/// A material property value as `getMaterialCacheKey` sees it.
pub(all) enum MaterialPropertyValue {
  Undefined
  Null
  Number(Double)
  Bool(Bool)
  String(String)
  /// Any non-texture object (colors, vectors, nodes, arrays, `defines`, ...).
  Object
  Texture(@core.Texture)
}

///|
/// The keys `getKeys` returns for each node material class: its own enumerable keys in
/// construction order, then the getters of its prototype chain (minus the skipped
/// `is*`, `_*`, `visible`, `version`, `uuid`, `name`, `opacity`, `userData`,
/// `iridescenceThicknessRange`), recorded from upstream r187.
let _render_object_material_keys_table : Array[(String, String, String)] = [
  (
    "Line2NodeMaterial", "blending,side,vertexColors,transparent,alphaHash,blendSrc,blendDst,blendEquation,blendSrcAlpha,blendDstAlpha,blendEquationAlpha,blendColor,blendAlpha,depthFunc,depthTest,depthWrite,stencilWriteMask,stencilFunc,stencilRef,stencilFuncMask,stencilFail,stencilZFail,stencilZPass,stencilWrite,clippingPlanes,clipIntersection,clipShadows,shadowSide,colorWrite,precision,polygonOffset,polygonOffsetFactor,polygonOffsetUnits,dithering,premultipliedAlpha,forceSinglePass,allowOverride,toneMapped,fog,lights,lightsNode,envNode,aoNode,colorNode,normalNode,opacityNode,backdropNode,backdropAlphaNode,alphaTestNode,maskNode,maskShadowNode,positionNode,geometryNode,depthNode,receivedShadowPositionNode,castShadowPositionNode,receivedShadowNode,castShadowNode,outputNode,mrtNode,fragmentNode,vertexNode,contextNode,color,map,linewidth,linecap,linejoin,scale,dashSize,gapSize,dashOffset,offsetNode,dashScaleNode,dashSizeNode,gapSizeNode",
    "lineColorNode,worldUnits,dashed,alphaToCoverage,type,alphaTest",
  ),
  (
    "LineBasicNodeMaterial", "blending,side,vertexColors,transparent,alphaHash,blendSrc,blendDst,blendEquation,blendSrcAlpha,blendDstAlpha,blendEquationAlpha,blendColor,blendAlpha,depthFunc,depthTest,depthWrite,stencilWriteMask,stencilFunc,stencilRef,stencilFuncMask,stencilFail,stencilZFail,stencilZPass,stencilWrite,clippingPlanes,clipIntersection,clipShadows,shadowSide,colorWrite,precision,polygonOffset,polygonOffsetFactor,polygonOffsetUnits,dithering,alphaToCoverage,premultipliedAlpha,forceSinglePass,allowOverride,toneMapped,fog,lights,lightsNode,envNode,aoNode,colorNode,normalNode,opacityNode,backdropNode,backdropAlphaNode,alphaTestNode,maskNode,maskShadowNode,positionNode,geometryNode,depthNode,receivedShadowPositionNode,castShadowPositionNode,receivedShadowNode,castShadowNode,outputNode,mrtNode,fragmentNode,vertexNode,contextNode,color,map,linewidth,linecap,linejoin",
    "type,alphaTest",
  ),
  (
    "LineDashedNodeMaterial", "blending,side,vertexColors,transparent,alphaHash,blendSrc,blendDst,blendEquation,blendSrcAlpha,blendDstAlpha,blendEquationAlpha,blendColor,blendAlpha,depthFunc,depthTest,depthWrite,stencilWriteMask,stencilFunc,stencilRef,stencilFuncMask,stencilFail,stencilZFail,stencilZPass,stencilWrite,clippingPlanes,clipIntersection,clipShadows,shadowSide,colorWrite,precision,polygonOffset,polygonOffsetFactor,polygonOffsetUnits,dithering,alphaToCoverage,premultipliedAlpha,forceSinglePass,allowOverride,toneMapped,fog,lights,lightsNode,envNode,aoNode,colorNode,normalNode,opacityNode,backdropNode,backdropAlphaNode,alphaTestNode,maskNode,maskShadowNode,positionNode,geometryNode,depthNode,receivedShadowPositionNode,castShadowPositionNode,receivedShadowNode,castShadowNode,outputNode,mrtNode,fragmentNode,vertexNode,contextNode,color,map,linewidth,linecap,linejoin,scale,dashSize,gapSize,dashOffset,offsetNode,dashScaleNode,dashSizeNode,gapSizeNode",
    "type,alphaTest",
  ),
  (
    "MeshBasicNodeMaterial", "blending,side,vertexColors,transparent,alphaHash,blendSrc,blendDst,blendEquation,blendSrcAlpha,blendDstAlpha,blendEquationAlpha,blendColor,blendAlpha,depthFunc,depthTest,depthWrite,stencilWriteMask,stencilFunc,stencilRef,stencilFuncMask,stencilFail,stencilZFail,stencilZPass,stencilWrite,clippingPlanes,clipIntersection,clipShadows,shadowSide,colorWrite,precision,polygonOffset,polygonOffsetFactor,polygonOffsetUnits,dithering,alphaToCoverage,premultipliedAlpha,forceSinglePass,allowOverride,toneMapped,fog,lights,lightsNode,envNode,aoNode,colorNode,normalNode,opacityNode,backdropNode,backdropAlphaNode,alphaTestNode,maskNode,maskShadowNode,positionNode,geometryNode,depthNode,receivedShadowPositionNode,castShadowPositionNode,receivedShadowNode,castShadowNode,outputNode,mrtNode,fragmentNode,vertexNode,contextNode,color,map,lightMap,lightMapIntensity,aoMap,aoMapIntensity,specularMap,alphaMap,envMap,envMapRotation,combine,reflectivity,refractionRatio,wireframe,wireframeLinewidth,wireframeLinecap,wireframeLinejoin",
    "type,alphaTest",
  ),
  (
    "MeshLambertNodeMaterial", "blending,side,vertexColors,transparent,alphaHash,blendSrc,blendDst,blendEquation,blendSrcAlpha,blendDstAlpha,blendEquationAlpha,blendColor,blendAlpha,depthFunc,depthTest,depthWrite,stencilWriteMask,stencilFunc,stencilRef,stencilFuncMask,stencilFail,stencilZFail,stencilZPass,stencilWrite,clippingPlanes,clipIntersection,clipShadows,shadowSide,colorWrite,precision,polygonOffset,polygonOffsetFactor,polygonOffsetUnits,dithering,alphaToCoverage,premultipliedAlpha,forceSinglePass,allowOverride,toneMapped,fog,lights,lightsNode,envNode,aoNode,colorNode,normalNode,opacityNode,backdropNode,backdropAlphaNode,alphaTestNode,maskNode,maskShadowNode,positionNode,geometryNode,depthNode,receivedShadowPositionNode,castShadowPositionNode,receivedShadowNode,castShadowNode,outputNode,mrtNode,fragmentNode,vertexNode,contextNode,emissiveNode,color,map,lightMap,lightMapIntensity,aoMap,aoMapIntensity,emissive,emissiveIntensity,emissiveMap,bumpMap,bumpScale,normalMap,normalMapType,normalScale,displacementMap,displacementScale,displacementBias,specularMap,alphaMap,envMap,envMapRotation,combine,reflectivity,envMapIntensity,refractionRatio,wireframe,wireframeLinewidth,wireframeLinecap,wireframeLinejoin,flatShading",
    "type,alphaTest",
  ),
  (
    "MeshMatcapNodeMaterial", "blending,side,vertexColors,transparent,alphaHash,blendSrc,blendDst,blendEquation,blendSrcAlpha,blendDstAlpha,blendEquationAlpha,blendColor,blendAlpha,depthFunc,depthTest,depthWrite,stencilWriteMask,stencilFunc,stencilRef,stencilFuncMask,stencilFail,stencilZFail,stencilZPass,stencilWrite,clippingPlanes,clipIntersection,clipShadows,shadowSide,colorWrite,precision,polygonOffset,polygonOffsetFactor,polygonOffsetUnits,dithering,alphaToCoverage,premultipliedAlpha,forceSinglePass,allowOverride,toneMapped,fog,lights,lightsNode,envNode,aoNode,colorNode,normalNode,opacityNode,backdropNode,backdropAlphaNode,alphaTestNode,maskNode,maskShadowNode,positionNode,geometryNode,depthNode,receivedShadowPositionNode,castShadowPositionNode,receivedShadowNode,castShadowNode,outputNode,mrtNode,fragmentNode,vertexNode,contextNode,defines,color,matcap,map,bumpMap,bumpScale,normalMap,normalMapType,normalScale,displacementMap,displacementScale,displacementBias,alphaMap,wireframe,wireframeLinewidth,flatShading",
    "type,alphaTest",
  ),
  (
    "MeshNormalNodeMaterial", "blending,side,vertexColors,transparent,alphaHash,blendSrc,blendDst,blendEquation,blendSrcAlpha,blendDstAlpha,blendEquationAlpha,blendColor,blendAlpha,depthFunc,depthTest,depthWrite,stencilWriteMask,stencilFunc,stencilRef,stencilFuncMask,stencilFail,stencilZFail,stencilZPass,stencilWrite,clippingPlanes,clipIntersection,clipShadows,shadowSide,colorWrite,precision,polygonOffset,polygonOffsetFactor,polygonOffsetUnits,dithering,alphaToCoverage,premultipliedAlpha,forceSinglePass,allowOverride,toneMapped,fog,lights,lightsNode,envNode,aoNode,colorNode,normalNode,opacityNode,backdropNode,backdropAlphaNode,alphaTestNode,maskNode,maskShadowNode,positionNode,geometryNode,depthNode,receivedShadowPositionNode,castShadowPositionNode,receivedShadowNode,castShadowNode,outputNode,mrtNode,fragmentNode,vertexNode,contextNode,bumpMap,bumpScale,normalMap,normalMapType,normalScale,displacementMap,displacementScale,displacementBias,wireframe,wireframeLinewidth,flatShading",
    "type,alphaTest",
  ),
  (
    "MeshPhongNodeMaterial", "blending,side,vertexColors,transparent,alphaHash,blendSrc,blendDst,blendEquation,blendSrcAlpha,blendDstAlpha,blendEquationAlpha,blendColor,blendAlpha,depthFunc,depthTest,depthWrite,stencilWriteMask,stencilFunc,stencilRef,stencilFuncMask,stencilFail,stencilZFail,stencilZPass,stencilWrite,clippingPlanes,clipIntersection,clipShadows,shadowSide,colorWrite,precision,polygonOffset,polygonOffsetFactor,polygonOffsetUnits,dithering,alphaToCoverage,premultipliedAlpha,forceSinglePass,allowOverride,toneMapped,fog,lights,lightsNode,envNode,aoNode,colorNode,normalNode,opacityNode,backdropNode,backdropAlphaNode,alphaTestNode,maskNode,maskShadowNode,positionNode,geometryNode,depthNode,receivedShadowPositionNode,castShadowPositionNode,receivedShadowNode,castShadowNode,outputNode,mrtNode,fragmentNode,vertexNode,contextNode,emissiveNode,shininessNode,specularNode,color,specular,shininess,map,lightMap,lightMapIntensity,aoMap,aoMapIntensity,emissive,emissiveIntensity,emissiveMap,bumpMap,bumpScale,normalMap,normalMapType,normalScale,displacementMap,displacementScale,displacementBias,specularMap,alphaMap,envMap,envMapRotation,combine,reflectivity,envMapIntensity,refractionRatio,wireframe,wireframeLinewidth,wireframeLinecap,wireframeLinejoin,flatShading",
    "type,alphaTest",
  ),
  (
    "MeshPhysicalNodeMaterial", "blending,side,vertexColors,transparent,alphaHash,blendSrc,blendDst,blendEquation,blendSrcAlpha,blendDstAlpha,blendEquationAlpha,blendColor,blendAlpha,depthFunc,depthTest,depthWrite,stencilWriteMask,stencilFunc,stencilRef,stencilFuncMask,stencilFail,stencilZFail,stencilZPass,stencilWrite,clippingPlanes,clipIntersection,clipShadows,shadowSide,colorWrite,precision,polygonOffset,polygonOffsetFactor,polygonOffsetUnits,dithering,alphaToCoverage,premultipliedAlpha,forceSinglePass,allowOverride,toneMapped,fog,lights,lightsNode,envNode,aoNode,colorNode,normalNode,opacityNode,backdropNode,backdropAlphaNode,alphaTestNode,maskNode,maskShadowNode,positionNode,geometryNode,depthNode,receivedShadowPositionNode,castShadowPositionNode,receivedShadowNode,castShadowNode,outputNode,mrtNode,fragmentNode,vertexNode,contextNode,emissiveNode,metalnessNode,roughnessNode,defines,color,roughness,metalness,map,lightMap,lightMapIntensity,aoMap,aoMapIntensity,emissive,emissiveIntensity,emissiveMap,bumpMap,bumpScale,normalMap,normalMapType,normalScale,displacementMap,displacementScale,displacementBias,roughnessMap,metalnessMap,alphaMap,envMap,envMapRotation,envMapIntensity,wireframe,wireframeLinewidth,wireframeLinecap,wireframeLinejoin,flatShading,clearcoatNode,clearcoatRoughnessNode,diffuseRoughnessNode,clearcoatNormalNode,sheenNode,sheenRoughnessNode,iridescenceNode,iridescenceIORNode,iridescenceThicknessNode,specularIntensityNode,specularColorNode,iorNode,transmissionNode,thicknessNode,attenuationDistanceNode,attenuationColorNode,dispersionNode,retroreflectivityNode,anisotropyNode,anisotropyRotation,anisotropyMap,clearcoatMap,clearcoatRoughness,clearcoatRoughnessMap,clearcoatNormalScale,clearcoatNormalMap,diffuseRoughnessMap,ior,iridescenceMap,iridescenceIOR,iridescenceThicknessMinimum,iridescenceThicknessMaximum,iridescenceThicknessMap,sheenColor,sheenColorMap,sheenRoughness,sheenRoughnessMap,transmissionMap,thickness,thicknessMap,attenuationDistance,attenuationColor,specularIntensity,specularIntensityMap,specularColor,specularColorMap",
    "useClearcoat,useDiffuseRoughness,useIridescence,useSheen,useAnisotropy,useTransmission,useDispersion,useRetroreflection,anisotropy,clearcoat,diffuseRoughness,iridescence,dispersion,retroreflectivity,sheen,transmission,type,alphaTest",
  ),
  (
    "MeshSSSNodeMaterial", "blending,side,vertexColors,transparent,alphaHash,blendSrc,blendDst,blendEquation,blendSrcAlpha,blendDstAlpha,blendEquationAlpha,blendColor,blendAlpha,depthFunc,depthTest,depthWrite,stencilWriteMask,stencilFunc,stencilRef,stencilFuncMask,stencilFail,stencilZFail,stencilZPass,stencilWrite,clippingPlanes,clipIntersection,clipShadows,shadowSide,colorWrite,precision,polygonOffset,polygonOffsetFactor,polygonOffsetUnits,dithering,alphaToCoverage,premultipliedAlpha,forceSinglePass,allowOverride,toneMapped,fog,lights,lightsNode,envNode,aoNode,colorNode,normalNode,opacityNode,backdropNode,backdropAlphaNode,alphaTestNode,maskNode,maskShadowNode,positionNode,geometryNode,depthNode,receivedShadowPositionNode,castShadowPositionNode,receivedShadowNode,castShadowNode,outputNode,mrtNode,fragmentNode,vertexNode,contextNode,emissiveNode,metalnessNode,roughnessNode,defines,color,roughness,metalness,map,lightMap,lightMapIntensity,aoMap,aoMapIntensity,emissive,emissiveIntensity,emissiveMap,bumpMap,bumpScale,normalMap,normalMapType,normalScale,displacementMap,displacementScale,displacementBias,roughnessMap,metalnessMap,alphaMap,envMap,envMapRotation,envMapIntensity,wireframe,wireframeLinewidth,wireframeLinecap,wireframeLinejoin,flatShading,clearcoatNode,clearcoatRoughnessNode,diffuseRoughnessNode,clearcoatNormalNode,sheenNode,sheenRoughnessNode,iridescenceNode,iridescenceIORNode,iridescenceThicknessNode,specularIntensityNode,specularColorNode,iorNode,transmissionNode,thicknessNode,attenuationDistanceNode,attenuationColorNode,dispersionNode,retroreflectivityNode,anisotropyNode,anisotropyRotation,anisotropyMap,clearcoatMap,clearcoatRoughness,clearcoatRoughnessMap,clearcoatNormalScale,clearcoatNormalMap,diffuseRoughnessMap,ior,iridescenceMap,iridescenceIOR,iridescenceThicknessMinimum,iridescenceThicknessMaximum,iridescenceThicknessMap,sheenColor,sheenColorMap,sheenRoughness,sheenRoughnessMap,transmissionMap,thickness,thicknessMap,attenuationDistance,attenuationColor,specularIntensity,specularIntensityMap,specularColor,specularColorMap,thicknessColorNode,thicknessDistortionNode,thicknessAmbientNode,thicknessAttenuationNode,thicknessPowerNode,thicknessScaleNode",
    "useSSS,anisotropy,clearcoat,diffuseRoughness,iridescence,dispersion,retroreflectivity,sheen,transmission,useClearcoat,useDiffuseRoughness,useIridescence,useSheen,useAnisotropy,useTransmission,useDispersion,useRetroreflection,anisotropy,clearcoat,diffuseRoughness,iridescence,dispersion,retroreflectivity,sheen,transmission,type,alphaTest",
  ),
  (
    "MeshStandardNodeMaterial", "blending,side,vertexColors,transparent,alphaHash,blendSrc,blendDst,blendEquation,blendSrcAlpha,blendDstAlpha,blendEquationAlpha,blendColor,blendAlpha,depthFunc,depthTest,depthWrite,stencilWriteMask,stencilFunc,stencilRef,stencilFuncMask,stencilFail,stencilZFail,stencilZPass,stencilWrite,clippingPlanes,clipIntersection,clipShadows,shadowSide,colorWrite,precision,polygonOffset,polygonOffsetFactor,polygonOffsetUnits,dithering,alphaToCoverage,premultipliedAlpha,forceSinglePass,allowOverride,toneMapped,fog,lights,lightsNode,envNode,aoNode,colorNode,normalNode,opacityNode,backdropNode,backdropAlphaNode,alphaTestNode,maskNode,maskShadowNode,positionNode,geometryNode,depthNode,receivedShadowPositionNode,castShadowPositionNode,receivedShadowNode,castShadowNode,outputNode,mrtNode,fragmentNode,vertexNode,contextNode,emissiveNode,metalnessNode,roughnessNode,defines,color,roughness,metalness,map,lightMap,lightMapIntensity,aoMap,aoMapIntensity,emissive,emissiveIntensity,emissiveMap,bumpMap,bumpScale,normalMap,normalMapType,normalScale,displacementMap,displacementScale,displacementBias,roughnessMap,metalnessMap,alphaMap,envMap,envMapRotation,envMapIntensity,wireframe,wireframeLinewidth,wireframeLinecap,wireframeLinejoin,flatShading",
    "type,alphaTest",
  ),
  (
    "MeshToonNodeMaterial", "blending,side,vertexColors,transparent,alphaHash,blendSrc,blendDst,blendEquation,blendSrcAlpha,blendDstAlpha,blendEquationAlpha,blendColor,blendAlpha,depthFunc,depthTest,depthWrite,stencilWriteMask,stencilFunc,stencilRef,stencilFuncMask,stencilFail,stencilZFail,stencilZPass,stencilWrite,clippingPlanes,clipIntersection,clipShadows,shadowSide,colorWrite,precision,polygonOffset,polygonOffsetFactor,polygonOffsetUnits,dithering,alphaToCoverage,premultipliedAlpha,forceSinglePass,allowOverride,toneMapped,fog,lights,lightsNode,envNode,aoNode,colorNode,normalNode,opacityNode,backdropNode,backdropAlphaNode,alphaTestNode,maskNode,maskShadowNode,positionNode,geometryNode,depthNode,receivedShadowPositionNode,castShadowPositionNode,receivedShadowNode,castShadowNode,outputNode,mrtNode,fragmentNode,vertexNode,contextNode,emissiveNode,defines,color,map,gradientMap,lightMap,lightMapIntensity,aoMap,aoMapIntensity,emissive,emissiveIntensity,emissiveMap,bumpMap,bumpScale,normalMap,normalMapType,normalScale,displacementMap,displacementScale,displacementBias,alphaMap,wireframe,wireframeLinewidth,wireframeLinecap,wireframeLinejoin",
    "type,alphaTest",
  ),
  (
    "NodeMaterial", "blending,side,vertexColors,transparent,alphaHash,blendSrc,blendDst,blendEquation,blendSrcAlpha,blendDstAlpha,blendEquationAlpha,blendColor,blendAlpha,depthFunc,depthTest,depthWrite,stencilWriteMask,stencilFunc,stencilRef,stencilFuncMask,stencilFail,stencilZFail,stencilZPass,stencilWrite,clippingPlanes,clipIntersection,clipShadows,shadowSide,colorWrite,precision,polygonOffset,polygonOffsetFactor,polygonOffsetUnits,dithering,alphaToCoverage,premultipliedAlpha,forceSinglePass,allowOverride,toneMapped,fog,lights,lightsNode,envNode,aoNode,colorNode,normalNode,opacityNode,backdropNode,backdropAlphaNode,alphaTestNode,maskNode,maskShadowNode,positionNode,geometryNode,depthNode,receivedShadowPositionNode,castShadowPositionNode,receivedShadowNode,castShadowNode,outputNode,mrtNode,fragmentNode,vertexNode,contextNode",
    "type,alphaTest",
  ),
  (
    "PointsNodeMaterial", "blending,side,vertexColors,transparent,alphaHash,blendSrc,blendDst,blendEquation,blendSrcAlpha,blendDstAlpha,blendEquationAlpha,blendColor,blendAlpha,depthFunc,depthTest,depthWrite,stencilWriteMask,stencilFunc,stencilRef,stencilFuncMask,stencilFail,stencilZFail,stencilZPass,stencilWrite,clippingPlanes,clipIntersection,clipShadows,shadowSide,colorWrite,precision,polygonOffset,polygonOffsetFactor,polygonOffsetUnits,dithering,premultipliedAlpha,forceSinglePass,allowOverride,toneMapped,fog,lights,lightsNode,envNode,aoNode,colorNode,normalNode,opacityNode,backdropNode,backdropAlphaNode,alphaTestNode,maskNode,maskShadowNode,positionNode,geometryNode,depthNode,receivedShadowPositionNode,castShadowPositionNode,receivedShadowNode,castShadowNode,outputNode,mrtNode,fragmentNode,vertexNode,contextNode,rotationNode,scaleNode,color,map,alphaMap,rotation,sizeNode,size",
    "alphaToCoverage,sizeAttenuation,type,alphaTest",
  ),
  (
    "ShadowNodeMaterial", "blending,side,vertexColors,transparent,alphaHash,blendSrc,blendDst,blendEquation,blendSrcAlpha,blendDstAlpha,blendEquationAlpha,blendColor,blendAlpha,depthFunc,depthTest,depthWrite,stencilWriteMask,stencilFunc,stencilRef,stencilFuncMask,stencilFail,stencilZFail,stencilZPass,stencilWrite,clippingPlanes,clipIntersection,clipShadows,shadowSide,colorWrite,precision,polygonOffset,polygonOffsetFactor,polygonOffsetUnits,dithering,alphaToCoverage,premultipliedAlpha,forceSinglePass,allowOverride,toneMapped,fog,lights,lightsNode,envNode,aoNode,colorNode,normalNode,opacityNode,backdropNode,backdropAlphaNode,alphaTestNode,maskNode,maskShadowNode,positionNode,geometryNode,depthNode,receivedShadowPositionNode,castShadowPositionNode,receivedShadowNode,castShadowNode,outputNode,mrtNode,fragmentNode,vertexNode,contextNode,color",
    "type,alphaTest",
  ),
  (
    "SpriteNodeMaterial", "blending,side,vertexColors,transparent,alphaHash,blendSrc,blendDst,blendEquation,blendSrcAlpha,blendDstAlpha,blendEquationAlpha,blendColor,blendAlpha,depthFunc,depthTest,depthWrite,stencilWriteMask,stencilFunc,stencilRef,stencilFuncMask,stencilFail,stencilZFail,stencilZPass,stencilWrite,clippingPlanes,clipIntersection,clipShadows,shadowSide,colorWrite,precision,polygonOffset,polygonOffsetFactor,polygonOffsetUnits,dithering,alphaToCoverage,premultipliedAlpha,forceSinglePass,allowOverride,toneMapped,fog,lights,lightsNode,envNode,aoNode,colorNode,normalNode,opacityNode,backdropNode,backdropAlphaNode,alphaTestNode,maskNode,maskShadowNode,positionNode,geometryNode,depthNode,receivedShadowPositionNode,castShadowPositionNode,receivedShadowNode,castShadowNode,outputNode,mrtNode,fragmentNode,vertexNode,contextNode,rotationNode,scaleNode,color,map,alphaMap,rotation",
    "sizeAttenuation,type,alphaTest",
  ),
  (
    "VolumeNodeMaterial", "blending,side,vertexColors,transparent,alphaHash,blendSrc,blendDst,blendEquation,blendSrcAlpha,blendDstAlpha,blendEquationAlpha,blendColor,blendAlpha,depthFunc,depthTest,depthWrite,stencilWriteMask,stencilFunc,stencilRef,stencilFuncMask,stencilFail,stencilZFail,stencilZPass,stencilWrite,clippingPlanes,clipIntersection,clipShadows,shadowSide,colorWrite,precision,polygonOffset,polygonOffsetFactor,polygonOffsetUnits,dithering,alphaToCoverage,premultipliedAlpha,forceSinglePass,allowOverride,toneMapped,fog,lights,lightsNode,envNode,aoNode,colorNode,normalNode,opacityNode,backdropNode,backdropAlphaNode,alphaTestNode,maskNode,maskShadowNode,positionNode,geometryNode,depthNode,receivedShadowPositionNode,castShadowPositionNode,receivedShadowNode,castShadowNode,outputNode,mrtNode,fragmentNode,vertexNode,contextNode,steps,offsetNode,scatteringNode",
    "type,alphaTest",
  ),
]

///|
/// `( own keys, getters )` of a recorded class.
let _render_object_material_keys : Map[String, (Array[String], Array[String])] = Map([],
)

///|
fn _render_object_split(csv : String) -> Array[String] {
  if csv == "" {
    []
  } else {
    csv.split(",").map(fn(s) { s.to_owned() }).collect()
  }
}

///|
/// Every own key of the recorded classes, in first-seen order: the order in which keys
/// a class lacks are appended when assigned (an approximation of assignment order).
let _render_object_all_own_keys : Array[String] = {
  let keys = []
  for entry in _render_object_material_keys_table {
    for key in _render_object_split(entry.1) {
      if !keys.contains(key) {
        keys.push(key)
      }
    }
  }
  keys
}

///|
/// `getKeys` of the core material classes (by `type`), for core materials rendered by
/// the node renderers, recorded from upstream r187 as above (added for the add-ons:
/// RoomEnvironment and friends render core materials through PMREMGenerator).
let _render_object_core_material_keys_table : Array[(String, String, String)] = [
  (
    "LineBasicMaterial", "type,blending,side,vertexColors,transparent,alphaHash,blendSrc,blendDst,blendEquation,blendSrcAlpha,blendDstAlpha,blendEquationAlpha,blendColor,blendAlpha,depthFunc,depthTest,depthWrite,stencilWriteMask,stencilFunc,stencilRef,stencilFuncMask,stencilFail,stencilZFail,stencilZPass,stencilWrite,clippingPlanes,clipIntersection,clipShadows,shadowSide,colorWrite,precision,polygonOffset,polygonOffsetFactor,polygonOffsetUnits,dithering,alphaToCoverage,premultipliedAlpha,forceSinglePass,allowOverride,toneMapped,color,map,linewidth,linecap,linejoin,fog",
    "alphaTest",
  ),
  (
    "LineDashedMaterial", "type,blending,side,vertexColors,transparent,alphaHash,blendSrc,blendDst,blendEquation,blendSrcAlpha,blendDstAlpha,blendEquationAlpha,blendColor,blendAlpha,depthFunc,depthTest,depthWrite,stencilWriteMask,stencilFunc,stencilRef,stencilFuncMask,stencilFail,stencilZFail,stencilZPass,stencilWrite,clippingPlanes,clipIntersection,clipShadows,shadowSide,colorWrite,precision,polygonOffset,polygonOffsetFactor,polygonOffsetUnits,dithering,alphaToCoverage,premultipliedAlpha,forceSinglePass,allowOverride,toneMapped,color,map,linewidth,linecap,linejoin,fog,scale,dashSize,gapSize",
    "alphaTest",
  ),
  (
    "MeshBasicMaterial", "type,blending,side,vertexColors,transparent,alphaHash,blendSrc,blendDst,blendEquation,blendSrcAlpha,blendDstAlpha,blendEquationAlpha,blendColor,blendAlpha,depthFunc,depthTest,depthWrite,stencilWriteMask,stencilFunc,stencilRef,stencilFuncMask,stencilFail,stencilZFail,stencilZPass,stencilWrite,clippingPlanes,clipIntersection,clipShadows,shadowSide,colorWrite,precision,polygonOffset,polygonOffsetFactor,polygonOffsetUnits,dithering,alphaToCoverage,premultipliedAlpha,forceSinglePass,allowOverride,toneMapped,color,map,lightMap,lightMapIntensity,aoMap,aoMapIntensity,specularMap,alphaMap,envMap,envMapRotation,combine,reflectivity,refractionRatio,wireframe,wireframeLinewidth,wireframeLinecap,wireframeLinejoin,fog",
    "alphaTest",
  ),
  (
    "MeshDepthMaterial", "type,blending,side,vertexColors,transparent,alphaHash,blendSrc,blendDst,blendEquation,blendSrcAlpha,blendDstAlpha,blendEquationAlpha,blendColor,blendAlpha,depthFunc,depthTest,depthWrite,stencilWriteMask,stencilFunc,stencilRef,stencilFuncMask,stencilFail,stencilZFail,stencilZPass,stencilWrite,clippingPlanes,clipIntersection,clipShadows,shadowSide,colorWrite,precision,polygonOffset,polygonOffsetFactor,polygonOffsetUnits,dithering,alphaToCoverage,premultipliedAlpha,forceSinglePass,allowOverride,toneMapped,depthPacking,map,alphaMap,displacementMap,displacementScale,displacementBias,wireframe,wireframeLinewidth",
    "alphaTest",
  ),
  (
    "MeshDistanceMaterial", "type,blending,side,vertexColors,transparent,alphaHash,blendSrc,blendDst,blendEquation,blendSrcAlpha,blendDstAlpha,blendEquationAlpha,blendColor,blendAlpha,depthFunc,depthTest,depthWrite,stencilWriteMask,stencilFunc,stencilRef,stencilFuncMask,stencilFail,stencilZFail,stencilZPass,stencilWrite,clippingPlanes,clipIntersection,clipShadows,shadowSide,colorWrite,precision,polygonOffset,polygonOffsetFactor,polygonOffsetUnits,dithering,alphaToCoverage,premultipliedAlpha,forceSinglePass,allowOverride,toneMapped,map,alphaMap,displacementMap,displacementScale,displacementBias",
    "alphaTest",
  ),
  (
    "MeshLambertMaterial", "type,blending,side,vertexColors,transparent,alphaHash,blendSrc,blendDst,blendEquation,blendSrcAlpha,blendDstAlpha,blendEquationAlpha,blendColor,blendAlpha,depthFunc,depthTest,depthWrite,stencilWriteMask,stencilFunc,stencilRef,stencilFuncMask,stencilFail,stencilZFail,stencilZPass,stencilWrite,clippingPlanes,clipIntersection,clipShadows,shadowSide,colorWrite,precision,polygonOffset,polygonOffsetFactor,polygonOffsetUnits,dithering,alphaToCoverage,premultipliedAlpha,forceSinglePass,allowOverride,toneMapped,color,map,lightMap,lightMapIntensity,aoMap,aoMapIntensity,emissive,emissiveIntensity,emissiveMap,bumpMap,bumpScale,normalMap,normalMapType,normalScale,displacementMap,displacementScale,displacementBias,specularMap,alphaMap,envMap,envMapRotation,combine,reflectivity,envMapIntensity,refractionRatio,wireframe,wireframeLinewidth,wireframeLinecap,wireframeLinejoin,flatShading,fog",
    "alphaTest",
  ),
  (
    "MeshMatcapMaterial", "type,blending,side,vertexColors,transparent,alphaHash,blendSrc,blendDst,blendEquation,blendSrcAlpha,blendDstAlpha,blendEquationAlpha,blendColor,blendAlpha,depthFunc,depthTest,depthWrite,stencilWriteMask,stencilFunc,stencilRef,stencilFuncMask,stencilFail,stencilZFail,stencilZPass,stencilWrite,clippingPlanes,clipIntersection,clipShadows,shadowSide,colorWrite,precision,polygonOffset,polygonOffsetFactor,polygonOffsetUnits,dithering,alphaToCoverage,premultipliedAlpha,forceSinglePass,allowOverride,toneMapped,defines,color,matcap,map,bumpMap,bumpScale,normalMap,normalMapType,normalScale,displacementMap,displacementScale,displacementBias,alphaMap,wireframe,wireframeLinewidth,flatShading,fog",
    "alphaTest",
  ),
  (
    "MeshNormalMaterial", "type,blending,side,vertexColors,transparent,alphaHash,blendSrc,blendDst,blendEquation,blendSrcAlpha,blendDstAlpha,blendEquationAlpha,blendColor,blendAlpha,depthFunc,depthTest,depthWrite,stencilWriteMask,stencilFunc,stencilRef,stencilFuncMask,stencilFail,stencilZFail,stencilZPass,stencilWrite,clippingPlanes,clipIntersection,clipShadows,shadowSide,colorWrite,precision,polygonOffset,polygonOffsetFactor,polygonOffsetUnits,dithering,alphaToCoverage,premultipliedAlpha,forceSinglePass,allowOverride,toneMapped,bumpMap,bumpScale,normalMap,normalMapType,normalScale,displacementMap,displacementScale,displacementBias,wireframe,wireframeLinewidth,flatShading",
    "alphaTest",
  ),
  (
    "MeshPhongMaterial", "type,blending,side,vertexColors,transparent,alphaHash,blendSrc,blendDst,blendEquation,blendSrcAlpha,blendDstAlpha,blendEquationAlpha,blendColor,blendAlpha,depthFunc,depthTest,depthWrite,stencilWriteMask,stencilFunc,stencilRef,stencilFuncMask,stencilFail,stencilZFail,stencilZPass,stencilWrite,clippingPlanes,clipIntersection,clipShadows,shadowSide,colorWrite,precision,polygonOffset,polygonOffsetFactor,polygonOffsetUnits,dithering,alphaToCoverage,premultipliedAlpha,forceSinglePass,allowOverride,toneMapped,color,specular,shininess,map,lightMap,lightMapIntensity,aoMap,aoMapIntensity,emissive,emissiveIntensity,emissiveMap,bumpMap,bumpScale,normalMap,normalMapType,normalScale,displacementMap,displacementScale,displacementBias,specularMap,alphaMap,envMap,envMapRotation,combine,reflectivity,envMapIntensity,refractionRatio,wireframe,wireframeLinewidth,wireframeLinecap,wireframeLinejoin,flatShading,fog",
    "alphaTest",
  ),
  (
    "MeshPhysicalMaterial", "type,blending,side,vertexColors,transparent,alphaHash,blendSrc,blendDst,blendEquation,blendSrcAlpha,blendDstAlpha,blendEquationAlpha,blendColor,blendAlpha,depthFunc,depthTest,depthWrite,stencilWriteMask,stencilFunc,stencilRef,stencilFuncMask,stencilFail,stencilZFail,stencilZPass,stencilWrite,clippingPlanes,clipIntersection,clipShadows,shadowSide,colorWrite,precision,polygonOffset,polygonOffsetFactor,polygonOffsetUnits,dithering,alphaToCoverage,premultipliedAlpha,forceSinglePass,allowOverride,toneMapped,defines,color,roughness,metalness,map,lightMap,lightMapIntensity,aoMap,aoMapIntensity,emissive,emissiveIntensity,emissiveMap,bumpMap,bumpScale,normalMap,normalMapType,normalScale,displacementMap,displacementScale,displacementBias,roughnessMap,metalnessMap,alphaMap,envMap,envMapRotation,envMapIntensity,wireframe,wireframeLinewidth,wireframeLinecap,wireframeLinejoin,flatShading,fog,anisotropyRotation,anisotropyMap,clearcoatMap,clearcoatRoughness,clearcoatRoughnessMap,clearcoatNormalScale,clearcoatNormalMap,diffuseRoughnessMap,ior,iridescenceMap,iridescenceIOR,iridescenceThicknessMinimum,iridescenceThicknessMaximum,iridescenceThicknessMap,sheenColor,sheenColorMap,sheenRoughness,sheenRoughnessMap,transmissionMap,thickness,thicknessMap,attenuationDistance,attenuationColor,specularIntensity,specularIntensityMap,specularColor,specularColorMap",
    "anisotropy,clearcoat,diffuseRoughness,iridescence,dispersion,retroreflectivity,sheen,transmission,alphaTest",
  ),
  (
    "MeshStandardMaterial", "type,blending,side,vertexColors,transparent,alphaHash,blendSrc,blendDst,blendEquation,blendSrcAlpha,blendDstAlpha,blendEquationAlpha,blendColor,blendAlpha,depthFunc,depthTest,depthWrite,stencilWriteMask,stencilFunc,stencilRef,stencilFuncMask,stencilFail,stencilZFail,stencilZPass,stencilWrite,clippingPlanes,clipIntersection,clipShadows,shadowSide,colorWrite,precision,polygonOffset,polygonOffsetFactor,polygonOffsetUnits,dithering,alphaToCoverage,premultipliedAlpha,forceSinglePass,allowOverride,toneMapped,defines,color,roughness,metalness,map,lightMap,lightMapIntensity,aoMap,aoMapIntensity,emissive,emissiveIntensity,emissiveMap,bumpMap,bumpScale,normalMap,normalMapType,normalScale,displacementMap,displacementScale,displacementBias,roughnessMap,metalnessMap,alphaMap,envMap,envMapRotation,envMapIntensity,wireframe,wireframeLinewidth,wireframeLinecap,wireframeLinejoin,flatShading,fog",
    "alphaTest",
  ),
  (
    "MeshToonMaterial", "type,blending,side,vertexColors,transparent,alphaHash,blendSrc,blendDst,blendEquation,blendSrcAlpha,blendDstAlpha,blendEquationAlpha,blendColor,blendAlpha,depthFunc,depthTest,depthWrite,stencilWriteMask,stencilFunc,stencilRef,stencilFuncMask,stencilFail,stencilZFail,stencilZPass,stencilWrite,clippingPlanes,clipIntersection,clipShadows,shadowSide,colorWrite,precision,polygonOffset,polygonOffsetFactor,polygonOffsetUnits,dithering,alphaToCoverage,premultipliedAlpha,forceSinglePass,allowOverride,toneMapped,defines,color,map,gradientMap,lightMap,lightMapIntensity,aoMap,aoMapIntensity,emissive,emissiveIntensity,emissiveMap,bumpMap,bumpScale,normalMap,normalMapType,normalScale,displacementMap,displacementScale,displacementBias,alphaMap,wireframe,wireframeLinewidth,wireframeLinecap,wireframeLinejoin,fog",
    "alphaTest",
  ),
  (
    "PointsMaterial", "type,blending,side,vertexColors,transparent,alphaHash,blendSrc,blendDst,blendEquation,blendSrcAlpha,blendDstAlpha,blendEquationAlpha,blendColor,blendAlpha,depthFunc,depthTest,depthWrite,stencilWriteMask,stencilFunc,stencilRef,stencilFuncMask,stencilFail,stencilZFail,stencilZPass,stencilWrite,clippingPlanes,clipIntersection,clipShadows,shadowSide,colorWrite,precision,polygonOffset,polygonOffsetFactor,polygonOffsetUnits,dithering,alphaToCoverage,premultipliedAlpha,forceSinglePass,allowOverride,toneMapped,color,map,alphaMap,size,sizeAttenuation,fog",
    "alphaTest",
  ),
  (
    "ShadowMaterial", "type,blending,side,vertexColors,transparent,alphaHash,blendSrc,blendDst,blendEquation,blendSrcAlpha,blendDstAlpha,blendEquationAlpha,blendColor,blendAlpha,depthFunc,depthTest,depthWrite,stencilWriteMask,stencilFunc,stencilRef,stencilFuncMask,stencilFail,stencilZFail,stencilZPass,stencilWrite,clippingPlanes,clipIntersection,clipShadows,shadowSide,colorWrite,precision,polygonOffset,polygonOffsetFactor,polygonOffsetUnits,dithering,alphaToCoverage,premultipliedAlpha,forceSinglePass,allowOverride,toneMapped,color,fog",
    "alphaTest",
  ),
  (
    "SpriteMaterial", "type,blending,side,vertexColors,transparent,alphaHash,blendSrc,blendDst,blendEquation,blendSrcAlpha,blendDstAlpha,blendEquationAlpha,blendColor,blendAlpha,depthFunc,depthTest,depthWrite,stencilWriteMask,stencilFunc,stencilRef,stencilFuncMask,stencilFail,stencilZFail,stencilZPass,stencilWrite,clippingPlanes,clipIntersection,clipShadows,shadowSide,colorWrite,precision,polygonOffset,polygonOffsetFactor,polygonOffsetUnits,dithering,alphaToCoverage,premultipliedAlpha,forceSinglePass,allowOverride,toneMapped,color,map,alphaMap,rotation,sizeAttenuation,fog",
    "alphaTest",
  ),
]

///|
/// The recorded keys of the material's node material class, or of the nearest
/// recorded superclass.
fn _render_object_class_keys(
  material : @core.Material,
) -> (Array[String], Array[String]) {
  let mut class_ : &NodeMaterialClass? = match NodeMaterial::of(material) {
    Some(nm) => Some(nm.class_)
    None => {
      // a core material, rendered through `NodeMaterial.fromMaterial`
      let name = "core:" + material.type_
      match _render_object_material_keys.get(name) {
        Some(keys) => return keys
        None =>
          for entry in _render_object_core_material_keys_table {
            if entry.0 == material.type_ {
              let keys = (
                _render_object_split(entry.1),
                _render_object_split(entry.2),
              )
              _render_object_material_keys.set(name, keys)
              return keys
            }
          }
      }
      abort(
        "RenderObject: getMaterialCacheKey needs a node material, got \{material.type_}",
      )
    }
  }
  while class_ is Some(c) {
    let name = c.class_name()
    match _render_object_material_keys.get(name) {
      Some(keys) => return keys
      None =>
        for entry in _render_object_material_keys_table {
          if entry.0 == name {
            let keys = (
              _render_object_split(entry.1),
              _render_object_split(entry.2),
            )
            _render_object_material_keys.set(name, keys)
            return keys
          }
        }
    }
    class_ = c.parent()
  }
  abort("RenderObject: no recorded keys for \{material.type_}")
}

///|
/// `getKeys( material )`: the class's own keys, then core properties set on the
/// material that the class does not define (as upstream appends assigned keys), then
/// the prototype getters.
fn _render_object_keys_of(material : @core.Material) -> Array[String] {
  let (own, getters) = _render_object_class_keys(material)
  let keys = own.copy()
  for key in _render_object_all_own_keys {
    if own.contains(key) || getters.contains(key) {
      continue
    }
    match _render_object_core_property(material, key) {
      Some(Null | Undefined) | None => ()
      Some(_) => keys.push(key)
    }
  }
  keys + getters
}

///|
fn _render_object_texture(texture : @core.Texture?) -> MaterialPropertyValue {
  match texture {
    Some(t) => Texture(t)
    None => Null
  }
}

///|
fn _render_object_node(node : Node?) -> MaterialPropertyValue {
  match node {
    Some(_) => Object
    None => Null
  }
}

///|
fn _render_object_opt_number(value : Double?) -> MaterialPropertyValue {
  match value {
    Some(v) => Number(v)
    None => Undefined
  }
}

///|
fn _render_object_opt_int(
  value : Int32?,
  absent : MaterialPropertyValue,
) -> MaterialPropertyValue {
  match value {
    Some(v) => Number(v.to_double())
    None => absent
  }
}

///|
fn _render_object_opt_bool(value : Bool?) -> MaterialPropertyValue {
  match value {
    Some(v) => Bool(v)
    None => Undefined
  }
}

///|
fn _render_object_opt_string(
  value : String?,
  absent : MaterialPropertyValue,
) -> MaterialPropertyValue {
  match value {
    Some(v) => String(v)
    None => absent
  }
}

///|
fn[T] _render_object_opt_object(value : T?) -> MaterialPropertyValue {
  match value {
    Some(_) => Object
    None => Undefined
  }
}

///|
/// A `NodeMaterial` node slot by upstream name.
fn _render_object_base_node_slot(
  nm : NodeMaterial,
  name : String,
) -> MaterialPropertyValue? {
  let slot = match name {
    "lightsNode" => nm.lights_node
    "envNode" => nm.env_node
    "aoNode" => nm.ao_node
    "colorNode" => nm.color_node
    "normalNode" => nm.normal_node
    "opacityNode" => nm.opacity_node
    "backdropNode" => nm.backdrop_node
    "backdropAlphaNode" => nm.backdrop_alpha_node
    "alphaTestNode" => nm.alpha_test_node
    "maskNode" => nm.mask_node
    "maskShadowNode" => nm.mask_shadow_node
    "positionNode" => nm.position_node
    "depthNode" => nm.depth_node
    "receivedShadowPositionNode" => nm.received_shadow_position_node
    "castShadowPositionNode" => nm.cast_shadow_position_node
    "castShadowNode" => nm.cast_shadow_node
    "outputNode" => nm.output_node
    "mrtNode" => nm.mrt_node
    "fragmentNode" => nm.fragment_node
    "vertexNode" => nm.vertex_node
    "contextNode" => nm.context_node
    // Upstream slots the `NodeMaterial` payload does not hold yet: always `null` here.
    "geometryNode" | "receivedShadowNode" => None
    _ => return None
  }
  Some(_render_object_node(slot))
}

///|
/// A core `Material` field by upstream name.
fn _render_object_core_property(
  m : @core.Material,
  name : String,
) -> MaterialPropertyValue? {
  let v : MaterialPropertyValue = match name {
    "type" => String(m.type_)
    "blending" => Number(m.blending.to_double())
    "side" => Number(m.side.to_double())
    "vertexColors" => Bool(m.vertex_colors)
    "transparent" => Bool(m.transparent)
    "alphaHash" => Bool(m.alpha_hash)
    "blendSrc" => Number(m.blend_src.to_double())
    "blendDst" => Number(m.blend_dst.to_double())
    "blendEquation" => Number(m.blend_equation.to_double())
    "blendSrcAlpha" => _render_object_opt_int(m.blend_src_alpha, Null)
    "blendDstAlpha" => _render_object_opt_int(m.blend_dst_alpha, Null)
    "blendEquationAlpha" => _render_object_opt_int(m.blend_equation_alpha, Null)
    "blendColor" => Object
    "blendAlpha" => Number(m.blend_alpha)
    "depthFunc" => Number(m.depth_func.to_double())
    "depthTest" => Bool(m.depth_test)
    "depthWrite" => Bool(m.depth_write)
    "stencilWriteMask" => Number(m.stencil_write_mask.to_double())
    "stencilFunc" => Number(m.stencil_func.to_double())
    "stencilRef" => Number(m.stencil_ref.to_double())
    "stencilFuncMask" => Number(m.stencil_func_mask.to_double())
    "stencilFail" => Number(m.stencil_fail.to_double())
    "stencilZFail" => Number(m.stencil_z_fail.to_double())
    "stencilZPass" => Number(m.stencil_z_pass.to_double())
    "stencilWrite" => Bool(m.stencil_write)
    "clippingPlanes" =>
      match m.clipping_planes {
        Some(_) => Object
        None => Null
      }
    "clipIntersection" => Bool(m.clip_intersection)
    "clipShadows" => Bool(m.clip_shadows)
    "shadowSide" => _render_object_opt_int(m.shadow_side, Null)
    "colorWrite" => Bool(m.color_write)
    "precision" => _render_object_opt_string(m.precision, Null)
    "polygonOffset" => Bool(m.polygon_offset)
    "polygonOffsetFactor" => Number(m.polygon_offset_factor)
    "polygonOffsetUnits" => Number(m.polygon_offset_units)
    "dithering" => Bool(m.dithering)
    "alphaToCoverage" => Bool(m.alpha_to_coverage)
    "premultipliedAlpha" => Bool(m.premultiplied_alpha)
    "forceSinglePass" => Bool(m.force_single_pass)
    "allowOverride" => Bool(m.allow_override)
    "toneMapped" => Bool(m.tone_mapped)
    "alphaTest" => Number(m.alpha_test())
    "fog" => _render_object_opt_bool(m.fog)
    "lights" => _render_object_opt_bool(m.lights)
    "defines" => _render_object_opt_object(m.defines)
    "color" => _render_object_opt_object(m.color)
    "map" => _render_object_texture(m.map)
    "linewidth" => _render_object_opt_number(m.linewidth)
    "linecap" => _render_object_opt_string(m.linecap, Undefined)
    "linejoin" => _render_object_opt_string(m.linejoin, Undefined)
    "scale" => _render_object_opt_number(m.scale)
    "dashSize" => _render_object_opt_number(m.dash_size)
    "gapSize" => _render_object_opt_number(m.gap_size)
    "lightMap" => _render_object_texture(m.light_map)
    "lightMapIntensity" => _render_object_opt_number(m.light_map_intensity)
    "aoMap" => _render_object_texture(m.ao_map)
    "aoMapIntensity" => _render_object_opt_number(m.ao_map_intensity)
    "specularMap" => _render_object_texture(m.specular_map)
    "alphaMap" => _render_object_texture(m.alpha_map)
    "envMap" => _render_object_texture(m.env_map)
    "envMapRotation" => _render_object_opt_object(m.env_map_rotation)
    "envMapIntensity" => _render_object_opt_number(m.env_map_intensity)
    "combine" => _render_object_opt_int(m.combine, Undefined)
    "reflectivity" => _render_object_opt_number(m.reflectivity())
    "refractionRatio" => _render_object_opt_number(m.refraction_ratio)
    "wireframe" => _render_object_opt_bool(m.wireframe)
    "wireframeLinewidth" => _render_object_opt_number(m.wireframe_linewidth)
    "wireframeLinecap" =>
      _render_object_opt_string(m.wireframe_linecap, Undefined)
    "wireframeLinejoin" =>
      _render_object_opt_string(m.wireframe_linejoin, Undefined)
    "displacementMap" => _render_object_texture(m.displacement_map)
    "displacementScale" => _render_object_opt_number(m.displacement_scale)
    "displacementBias" => _render_object_opt_number(m.displacement_bias)
    "emissive" => _render_object_opt_object(m.emissive)
    "emissiveIntensity" => _render_object_opt_number(m.emissive_intensity)
    "emissiveMap" => _render_object_texture(m.emissive_map)
    "bumpMap" => _render_object_texture(m.bump_map)
    "bumpScale" => _render_object_opt_number(m.bump_scale)
    "normalMap" => _render_object_texture(m.normal_map)
    "normalMapType" => _render_object_opt_int(m.normal_map_type, Undefined)
    "normalScale" => _render_object_opt_object(m.normal_scale)
    "flatShading" => _render_object_opt_bool(m.flat_shading)
    "matcap" => _render_object_texture(m.matcap)
    "gradientMap" => _render_object_texture(m.gradient_map)
    "specular" => _render_object_opt_object(m.specular)
    "shininess" => _render_object_opt_number(m.shininess)
    "roughness" => _render_object_opt_number(m.roughness)
    "metalness" => _render_object_opt_number(m.metalness)
    "roughnessMap" => _render_object_texture(m.roughness_map)
    "metalnessMap" => _render_object_texture(m.metalness_map)
    "size" => _render_object_opt_number(m.size)
    "sizeAttenuation" => _render_object_opt_bool(m.size_attenuation)
    "depthPacking" => _render_object_opt_int(m.depth_packing, Undefined)
    "rotation" => _render_object_opt_number(m.rotation)
    "anisotropyRotation" => _render_object_opt_number(m.anisotropy_rotation)
    "anisotropyMap" => _render_object_texture(m.anisotropy_map)
    "clearcoatMap" => _render_object_texture(m.clearcoat_map)
    "clearcoatRoughness" => _render_object_opt_number(m.clearcoat_roughness)
    "clearcoatRoughnessMap" => _render_object_texture(m.clearcoat_roughness_map)
    "clearcoatNormalScale" =>
      _render_object_opt_object(m.clearcoat_normal_scale)
    "clearcoatNormalMap" => _render_object_texture(m.clearcoat_normal_map)
    "diffuseRoughnessMap" => _render_object_texture(m.diffuse_roughness_map)
    "ior" => _render_object_opt_number(m.ior)
    "iridescenceMap" => _render_object_texture(m.iridescence_map)
    "iridescenceIOR" => _render_object_opt_number(m.iridescence_ior)
    "iridescenceThicknessMinimum" =>
      _render_object_opt_number(m.iridescence_thickness_minimum)
    "iridescenceThicknessMaximum" =>
      _render_object_opt_number(m.iridescence_thickness_maximum)
    "iridescenceThicknessMap" =>
      _render_object_texture(m.iridescence_thickness_map)
    "sheenColor" => _render_object_opt_object(m.sheen_color)
    "sheenColorMap" => _render_object_texture(m.sheen_color_map)
    "sheenRoughness" => _render_object_opt_number(m.sheen_roughness)
    "sheenRoughnessMap" => _render_object_texture(m.sheen_roughness_map)
    "transmissionMap" => _render_object_texture(m.transmission_map)
    "thickness" => _render_object_opt_number(m.thickness)
    "thicknessMap" => _render_object_texture(m.thickness_map)
    "attenuationDistance" => _render_object_opt_number(m.attenuation_distance)
    "attenuationColor" => _render_object_opt_object(m.attenuation_color)
    "specularIntensity" => _render_object_opt_number(m.specular_intensity)
    "specularIntensityMap" => _render_object_texture(m.specular_intensity_map)
    "specularColor" => _render_object_opt_object(m.specular_color)
    "specularColorMap" => _render_object_texture(m.specular_color_map)
    "anisotropy" => _render_object_opt_number(m.anisotropy())
    "clearcoat" => _render_object_opt_number(m.clearcoat())
    "diffuseRoughness" => _render_object_opt_number(m.diffuse_roughness())
    "iridescence" => _render_object_opt_number(m.iridescence())
    "dispersion" => _render_object_opt_number(m.dispersion())
    "retroreflectivity" => _render_object_opt_number(m.retroreflectivity())
    "sheen" => _render_object_opt_number(m.sheen())
    "transmission" => _render_object_opt_number(m.transmission())
    _ => return None
  }
  Some(v)
}

///|
/// `material[ name ]` for a node material: the class's own properties first, then the
/// `NodeMaterial` slots, then the core fields; `Undefined` for anything else.
pub fn material_property(
  material : @core.Material,
  name : String,
) -> MaterialPropertyValue {
  match NodeMaterial::of(material) {
    Some(nm) => {
      if nm.class_.get_property(material, name) is Some(v) {
        return v
      }
      if _render_object_base_node_slot(nm, name) is Some(v) {
        return v
      }
    }
    None => ()
  }
  match _render_object_core_property(material, name) {
    Some(v) => v
    None => Undefined
  }
}

///|
/// `material[ name ] && material[ name ].isNode`, for a node slot by upstream name.
pub fn material_node_property_is_set(
  material : @core.Material,
  name : String,
) -> Bool {
  material_property(material, name) is Object
}

///|
let _render_object_enum_properties : Array[String] = [
  "side", "blending", "combine", "normalMapType",
]

///|
/// The `valueKey` of one material property.
fn _render_object_value_key(
  property : String,
  value : MaterialPropertyValue,
  is_webgpu : Bool,
) -> String {
  match value {
    Number(n) =>
      if _render_object_enum_properties.contains(property) {
        render_object_js_string(n)
      } else if n != 0.0 {
        "1"
      } else {
        "0"
      }
    Object => "{}"
    Texture(t) => {
      let mut value_key = "{"
      value_key += t.mapping.to_string()
      value_key += t.channel.to_string()
      if is_webgpu {
        value_key += t.mag_filter.to_string()
        value_key += t.min_filter.to_string()
        value_key += t.wrap_s.to_string()
        value_key += t.wrap_t.to_string()
        value_key += _render_object_wrap_r(t)
      }
      value_key + "}"
    }
    Bool(b) => b.to_string()
    String(s) => s
    Null => "null"
    Undefined => "undefined"
  }
}

///|
/// `texture.wrapR`: only the 3D and array textures define it (`undefined` otherwise).
fn _render_object_wrap_r(t : @core.Texture) -> String {
  if t.texture_type
    is (Data3DTexture | DataArrayTexture | CompressedArrayTexture) ||
    t.has_extension_flag("is3DTexture") {
    t.wrap_r.to_string()
  } else {
    "undefined"
  }
}

///|
/// The key of `attributesId`: an interleaved buffer's uuid or an attribute's id.
#derive(Eq)
priv enum RenderObjectAttributeKey {
  Uuid(String)
  Id(Int32)
  /// `GLBufferAttribute`, which has no id.
  NoId
}

///|
fn _render_object_attribute_key(
  attribute : @core.GeometryAttribute,
) -> RenderObjectAttributeKey {
  match attribute {
    Buffer(a) => Id(a.id)
    Interleaved(a) => Uuid(a.data.uuid)
    GL(_) => NoId
  }
}

///|
/// `{ vertexCount, firstVertex, instanceCount, firstInstance }`.
pub(all) struct DrawParameters {
  mut vertex_count : Int32
  mut first_vertex : Int32
  /// `Infinity` for an instanced geometry without a count.
  mut instance_count : Double
  mut first_instance : Int32
}

///|
/// A drawable: one object with one material in one render context, and its node
/// build, bindings, attributes and pipeline.
pub(all) struct RenderObject {
  id : Int32
  _nodes : NodeManager
  _geometries : Geometries
  renderer : Renderer
  object : @core.Object3D
  material : @core.Material
  scene : @core.Object3D
  mut camera : @core.Object3D
  lights_node : Node
  context : RenderContext
  mut geometry : @core.BufferGeometry
  mut geometry_version : Int32
  mut version : Int32
  mut draw_range : @core.DrawRange?
  mut attributes : Array[@core.GeometryAttribute]?
  priv mut attributes_id : Map[String, RenderObjectAttributeKey]?
  mut pipeline : Pipeline?
  mut group : @core.GeometryGroup?
  mut vertex_buffers : Array[AttributeBuffer]?
  mut draw_params : DrawParameters?
  /// The `BundleGroup` the object is rendered in.
  mut bundle : @core.Object3D?
  mut clipping_context : ClippingContext?
  mut clipping_context_cache_key : String
  mut initial_nodes_cache_key : Double
  mut initial_cache_key : Double
  mut initial_geometry_cache_key : String
  mut _node_builder_state : NodeBuilderState?
  mut _bindings : Array[BindGroup]?
  mut _monitor : NodeMaterialObserver?
  _source_material : @core.Material?
  mut source_material_version : Int32
  /// Set by `RenderObjects`; `None` is `null`.
  mut on_dispose : (() -> Unit)?
  mut on_material_dispose : (@core.Event) -> Unit
  mut on_geometry_dispose : (@core.Event) -> Unit
  mut on_object_dispose : (@core.Event) -> Unit
  mut on_lights_node_dispose : (@core.Event) -> Unit
}

///|
/// `new RenderObject( nodes, geometries, renderer, object, material, scene, camera,
/// lightsNode, renderContext, clippingContext )`.
pub fn RenderObject::new(
  nodes : NodeManager,
  geometries : Geometries,
  renderer : Renderer,
  object : @core.Object3D,
  material : @core.Material,
  scene : @core.Object3D,
  camera : @core.Object3D,
  lights_node : Node,
  render_context : RenderContext,
  clipping_context : ClippingContext?,
) -> RenderObject {
  let id = _render_object_id.val
  _render_object_id.val += 1
  let geometry = match object.get_geometry() {
    Some(g) => g
    None =>
      abort(
        "TypeError: Cannot read properties of undefined (reading 'addEventListener')",
      )
  }
  let noop = fn(_e : @core.Event) {  }
  let render_object : RenderObject = {
    id,
    _nodes: nodes,
    _geometries: geometries,
    renderer,
    object,
    material,
    scene,
    camera,
    lights_node,
    context: render_context,
    geometry,
    geometry_version: 0,
    version: material.version,
    draw_range: None,
    attributes: None,
    attributes_id: None,
    pipeline: None,
    group: None,
    vertex_buffers: None,
    draw_params: None,
    bundle: None,
    clipping_context,
    clipping_context_cache_key: match clipping_context {
      Some(c) => c.cache_key
      None => ""
    },
    initial_nodes_cache_key: 0.0,
    initial_cache_key: 0.0,
    initial_geometry_cache_key: "",
    _node_builder_state: None,
    _bindings: None,
    _monitor: None,
    _source_material: renderer._current_source_material,
    source_material_version: 0,
    on_dispose: None,
    on_material_dispose: noop,
    on_geometry_dispose: noop,
    on_object_dispose: noop,
    on_lights_node_dispose: noop,
  }
  render_object.initial_nodes_cache_key = render_object.get_dynamic_cache_key()
  render_object.initial_cache_key = render_object.get_cache_key()
  render_object.initial_geometry_cache_key = render_object.get_geometry_cache_key()
  render_object.source_material_version = match render_object._source_material {
    Some(m) => m.version
    None => 0
  }
  render_object.on_material_dispose = fn(_e) { render_object.dispose() }
  render_object.on_geometry_dispose = fn(_e) {
    render_object._geometries.delete_node_attributes(render_object)
    render_object._geometries.delete_vertex_state(render_object)
    render_object.attributes = None
    render_object.attributes_id = None
  }
  render_object.on_object_dispose = fn(_e) { render_object.dispose() }
  render_object.on_lights_node_dispose = fn(_e) { render_object.dispose() }
  object.add_event_listener("dispose", render_object.on_object_dispose)
  material.add_event_listener("dispose", render_object.on_material_dispose)
  geometry.add_event_listener("dispose", render_object.on_geometry_dispose)
  lights_node.add_event_listener(
    "dispose",
    render_object.on_lights_node_dispose,
  )
  match render_object._source_material {
    Some(m) =>
      m.add_event_listener("dispose", render_object.on_material_dispose)
    None => ()
  }
  render_object
}

///|
/// `updateClipping( context )`.
pub fn RenderObject::update_clipping(
  self : RenderObject,
  context : ClippingContext?,
) -> Unit {
  self.clipping_context = context
}

///|
/// `get clippingNeedsUpdate()`: whether the clipping context changed since the last
/// call (which records the new key).
pub fn RenderObject::clipping_needs_update(self : RenderObject) -> Bool {
  match self.clipping_context {
    None => false
    Some(c) =>
      if c.cache_key == self.clipping_context_cache_key {
        false
      } else {
        self.clipping_context_cache_key = c.cache_key
        true
      }
  }
}

///|
/// `get hardwareClippingPlanes()`.
pub fn RenderObject::hardware_clipping_planes(self : RenderObject) -> Int32 {
  if self.get_node_builder_state().hardware_clipping {
    match self.clipping_context {
      Some(c) => c.union_clipping_count()
      None =>
        abort(
          "TypeError: Cannot read properties of null (reading 'unionClippingCount')",
        )
    }
  } else {
    0
  }
}

///|
/// `getNodeBuilderState()`.
pub fn RenderObject::get_node_builder_state(
  self : RenderObject,
) -> NodeBuilderState {
  match self._node_builder_state {
    Some(s) => s
    None => {
      let s = self._nodes.get_for_render(self)
      self._node_builder_state = Some(s)
      s
    }
  }
}

///|
/// `getMonitor()`.
pub fn RenderObject::get_monitor(self : RenderObject) -> NodeMaterialObserver? {
  match self._monitor {
    Some(m) => Some(m)
    None => {
      self._monitor = self.get_node_builder_state().observer
      self._monitor
    }
  }
}

///|
/// `getBindings()`.
pub fn RenderObject::get_bindings(self : RenderObject) -> Array[BindGroup] {
  match self._bindings {
    Some(b) => b
    None => {
      let b = self
        .get_node_builder_state()
        .create_bindings(self.renderer._bindings, Some(self.context))
      self._bindings = Some(b)
      b
    }
  }
}

///|
/// `getBindingGroup( name )`; `None` is `undefined`.
pub fn RenderObject::get_binding_group(
  self : RenderObject,
  name : String,
) -> BindGroup? {
  for binding_group in self.get_bindings() {
    if binding_group.name == name {
      return Some(binding_group)
    }
  }
  None
}

///|
/// `getIndex()`.
pub fn RenderObject::get_index(self : RenderObject) -> @core.GeometryAttribute? {
  self._geometries.get_index(self)
}

///|
/// `getIndirect()`.
pub fn RenderObject::get_indirect(
  self : RenderObject,
) -> @core.BufferAttribute? {
  self._geometries.get_indirect(self)
}

///|
/// `getIndirectOffset()`.
pub fn RenderObject::get_indirect_offset(self : RenderObject) -> Array[Int32] {
  self._geometries.get_indirect_offset(self)
}

///|
/// `getChainArray()`: the keys of this render object in `RenderObjects`.
pub fn RenderObject::get_chain_array(
  self : RenderObject,
) -> Array[@core.JsValue] {
  let keys = [
    @core.JsValue::of(self.object),
    @core.JsValue::of(self.material),
    @core.JsValue::of(self.context),
    @core.JsValue::of(self.lights_node),
  ]
  match self._source_material {
    Some(m) => keys.push(@core.JsValue::of(m))
    None => ()
  }
  keys
}

///|
/// `setGeometry( geometry )`.
pub fn RenderObject::set_geometry(
  self : RenderObject,
  geometry : @core.BufferGeometry,
) -> Unit {
  self.geometry.remove_event_listener("dispose", self.on_geometry_dispose)
  self.geometry = geometry
  self.geometry.add_event_listener("dispose", self.on_geometry_dispose)
  self.attributes = None
  self.attributes_id = None
  self.geometry_version += 1
}

///|
/// `nodeAttribute.node && nodeAttribute.node.attribute`: a buffer attribute node with
/// its attribute set.
fn _render_object_attribute_node(node : Node?) -> Node? {
  match node {
    Some(n) =>
      match BufferAttributeNode::of(n) {
        Some({ attribute: Some(_), .. }) => Some(n)
        _ => None
      }
    None => None
  }
}

///|
/// `getAttributes()`: the attributes the node build reads, from the geometry or from
/// buffer attribute nodes.
pub fn RenderObject::get_attributes(
  self : RenderObject,
) -> Array[@core.GeometryAttribute] {
  match self.attributes {
    Some(a) => return a
    None => ()
  }
  let node_attributes = self.get_node_builder_state().node_attributes
  let geometry = self.geometry
  let attributes = []
  let vertex_buffers : Array[AttributeBuffer] = []
  let attributes_id : Map[String, RenderObjectAttributeKey] = Map([])
  for node_attribute in node_attributes {
    let attribute = match _render_object_attribute_node(node_attribute.node) {
      Some(node) => _render_object_node_object_attribute(node, self.object)
      None => {
        let attribute = geometry.get_attribute(node_attribute.name)
        match attribute {
          Some(a) =>
            attributes_id.set(
              node_attribute.name,
              _render_object_attribute_key(a),
            )
          None => ()
        }
        attribute
      }
    }
    guard attribute is Some(attribute) else { continue }
    attributes.push(attribute)
    let buffer_attribute : AttributeBuffer = match attribute {
      Buffer(a) => Buffer(a)
      Interleaved(a) => interleaved_attribute_buffer(a)
      GL(a) => GL(a)
    }
    if !vertex_buffers.iter().any(fn(b) { b.same(buffer_attribute) }) {
      vertex_buffers.push(buffer_attribute)
    }
  }
  self.attributes = Some(attributes)
  self.attributes_id = Some(attributes_id)
  self.vertex_buffers = Some(vertex_buffers)
  attributes
}

///|
/// `getVertexBuffers()`.
pub fn RenderObject::get_vertex_buffers(
  self : RenderObject,
) -> Array[AttributeBuffer] {
  if self.vertex_buffers is None {
    self.get_attributes() |> ignore
  }
  self.vertex_buffers.unwrap()
}

///|
/// `object.count`: `None` is `undefined` (objects other than meshes and sprites).
fn _render_object_count(object : @core.Object3D) -> Int32? {
  match object.kind {
    Mesh(mesh) => Some(mesh.count)
    Sprite(_) => Some(1)
    _ => None
  }
}

///|
/// `getDrawParameters()`: what to draw, or `None` (`null`) when nothing is drawn.
pub fn RenderObject::get_draw_parameters(
  self : RenderObject,
) -> DrawParameters? {
  let object = self.object
  let material = self.material
  let geometry = self.geometry
  let group = self.group
  let draw_params = match self.draw_params {
    Some(p) => p
    None => {
      let p = {
        vertex_count: 0,
        first_vertex: 0,
        instance_count: 0.0,
        first_instance: 0,
      }
      self.draw_params = Some(p)
      p
    }
  }
  let index = self.get_index()
  let mut instance_count = 1.0
  if geometry.is_instanced_buffer_geometry {
    instance_count = geometry.instance_count
  } else if _render_object_count(object) is Some(count) {
    instance_count = @webgl.js_math_max(0.0, count.to_double())
  }
  if instance_count == 0.0 {
    return None
  }
  draw_params.instance_count = instance_count
  if object.is_batched_mesh() {
    return Some(draw_params)
  }
  let mut range_factor = 1.0
  if material.wireframe == Some(true) &&
    !object.is_points() &&
    !object.is_line_segments() &&
    !object.is_line() &&
    !object.is_line_loop() {
    range_factor = 2.0
  }
  let draw_range = match self.draw_range {
    Some(r) => r
    None => abort("TypeError: Cannot destructure property 'drawRange' of null")
  }
  let mut first_vertex = draw_range.start.to_double() * range_factor
  let mut last_vertex = (draw_range.start.to_double() + draw_range.count) *
    range_factor
  match group {
    Some(g) => {
      first_vertex = @webgl.js_math_max(
        first_vertex,
        g.start.to_double() * range_factor,
      )
      last_vertex = @webgl.js_math_min(
        last_vertex,
        (g.start.to_double() + g.count) * range_factor,
      )
    }
    None => ()
  }
  let position = geometry.get_attribute("position")
  let mut item_count = _render_object_infinity
  match index {
    Some(i) => item_count = i.count().to_double()
    None =>
      match position {
        Some(p) => item_count = p.count().to_double()
        None => ()
      }
  }
  first_vertex = @webgl.js_math_max(first_vertex, 0.0)
  last_vertex = @webgl.js_math_min(last_vertex, item_count)
  let count = last_vertex - first_vertex
  if count < 0.0 || count == _render_object_infinity {
    return None
  }
  draw_params.vertex_count = count.to_int()
  draw_params.first_vertex = first_vertex.to_int()
  Some(draw_params)
}

///|
/// `getGeometryCacheKey()`: the attribute layout and morph targets of the geometry.
pub fn RenderObject::get_geometry_cache_key(self : RenderObject) -> String {
  let geometry = self.geometry
  let mut cache_key = ""
  let names = geometry.attributes.keys().collect()
  names.sort_by(render_object_js_compare)
  for name in names {
    let attribute = geometry.attributes.get(name).unwrap()
    cache_key += name + ","
    let item_size = attribute.item_size()
    if item_size != 0 {
      cache_key += item_size.to_string() + ","
    }
    if attribute.normalized() {
      cache_key += "n,"
    }
  }
  let morph_names = geometry.morph_attributes.keys().collect()
  morph_names.sort_by(render_object_js_compare)
  for name in morph_names {
    let targets = geometry.morph_attributes.get(name).unwrap()
    cache_key += "morph-" + name + ","
    for attribute in targets {
      cache_key += (match attribute {
          Buffer(a) => a.id.to_string()
          _ => "undefined"
        }) +
        ","
    }
  }
  cache_key
}

///|
/// `getInstanceDataKey( attribute )`.
fn _render_object_instance_data_key(
  attribute : @core.BufferAttribute?,
) -> String {
  match attribute {
    None => "-"
    Some(a) => if is_storage_instanced_buffer_attribute(a) { "s" } else { "a" }
  }
}

///|
/// `getMaterialCacheKey()`: a hash of everything about the material and object that
/// changes the generated shaders.
pub fn RenderObject::get_material_cache_key(self : RenderObject) -> Double {
  let object = self.object
  let material = self.material
  let renderer = self.renderer
  let scene = self.scene
  let mut cache_key = self._nodes.get_custom_program_cache_key(material, scene)
  let is_webgpu = renderer.backend.has_flag("isWebGPUBackend")
  for property in _render_object_keys_of(material) {
    let value = material_property(material, property)
    cache_key += _render_object_value_key(property, value, is_webgpu) + ","
  }
  cache_key += self.clipping_context_cache_key + ","
  if object.get_geometry() is Some(_) {
    cache_key += self.get_geometry_cache_key()
  }
  match object.kind {
    Mesh({ kind: SkinnedMesh({ skeleton: Some(skeleton), .. }), .. }) =>
      cache_key += skeleton.bones.length().to_string() + ","
    _ => ()
  }
  match object.kind {
    Mesh({ kind: BatchedMesh(batched), .. }) => {
      cache_key += (match batched._matrices_texture {
          Some(t) => t.uuid
          None =>
            abort("TypeError: Cannot read properties of null (reading 'uuid')")
        }) +
        ","
      match batched._colors_texture {
        Some(t) => cache_key += t.uuid + ","
        None => ()
      }
    }
    _ => ()
  }
  match object.kind {
    Mesh({ kind: InstancedMesh(instanced), .. }) =>
      cache_key += _render_object_instance_data_key(
          Some(instanced.instance_matrix),
        ) +
        _render_object_instance_data_key(instanced.instance_color) +
        (if instanced.morph_texture is Some(_) { "m" } else { "" }) +
        ","
    _ =>
      match _render_object_count(object) {
        Some(count) if count > 1 => cache_key += object.uuid + ","
        _ => ()
      }
  }
  cache_key += self.context.state_key + ","
  cache_key += object.receive_shadow.to_string() + ","
  hash_string(cache_key)
}

///|
/// `get needsGeometryUpdate()`: whether the object's geometry or its attributes changed.
pub fn RenderObject::needs_geometry_update(self : RenderObject) -> Bool {
  match self.object.get_geometry() {
    Some(g) if g.id != self.geometry.id => return true
    None =>
      abort("TypeError: Cannot read properties of undefined (reading 'id')")
    _ => ()
  }
  match self.attributes {
    Some(attributes) => {
      match self.attributes_id {
        Some(attributes_id) =>
          for name, id in attributes_id {
            match self.geometry.get_attribute(name) {
              None => return true
              Some(attribute) =>
                if id != _render_object_attribute_key(attribute) {
                  return true
                }
            }
          }
        None => ()
      }
      for node_attribute in self.get_node_builder_state().node_attributes {
        match _render_object_attribute_node(node_attribute.node) {
          Some(node) =>
            match _render_object_node_object_attribute(node, self.object) {
              Some(attribute) =>
                if !attributes
                  .iter()
                  .any(fn(a) { _render_object_same_attribute(a, attribute) }) {
                  return true
                }
              None => ()
            }
          None => ()
        }
      }
    }
    None => ()
  }
  false
}

///|
fn _render_object_same_attribute(
  a : @core.GeometryAttribute,
  b : @core.GeometryAttribute,
) -> Bool {
  match (a, b) {
    (Buffer(x), Buffer(y)) => physical_equal(x, y)
    (Interleaved(x), Interleaved(y)) => physical_equal(x, y)
    (GL(x), GL(y)) => physical_equal(x, y)
    _ => false
  }
}

///|
/// `get needsUpdate()`: whether the dynamic cache key or the clipping changed.
pub fn RenderObject::needs_update(self : RenderObject) -> Bool {
  self.initial_nodes_cache_key != self.get_dynamic_cache_key() ||
  self.clipping_needs_update()
}

///|
/// `getDynamicCacheKey()`: the environment, camera and context-node state.
pub fn RenderObject::get_dynamic_cache_key(self : RenderObject) -> Double {
  let mut environment_key = 0.0
  if !self.material.has_extension_flag("isShadowPassMaterial") {
    environment_key = self._nodes.get_cache_key(self.scene, self.lights_node)
  }
  let cameras = match self.camera.kind {
    Camera({ kind: PerspectiveCamera({ array_camera: Some(a), .. }), .. }) =>
      a.cameras.length()
    _ => 0
  }
  hash_array([
    environment_key,
    cameras.to_double(),
    if self.object.receive_shadow {
      1.0
    } else {
      0.0
    },
    self.renderer.context_node.id.to_double(),
    self.renderer.context_node.version.to_double(),
  ])
}

///|
/// `getCacheKey()`: the material key plus the dynamic key (a numeric sum, as upstream).
pub fn RenderObject::get_cache_key(self : RenderObject) -> Double {
  self.get_material_cache_key() + self.get_dynamic_cache_key()
}

///|
/// `dispose()`: removes the listeners and calls `onDispose`.
pub fn RenderObject::dispose(self : RenderObject) -> Unit {
  self.object.remove_event_listener("dispose", self.on_object_dispose)
  self.material.remove_event_listener("dispose", self.on_material_dispose)
  self.geometry.remove_event_listener("dispose", self.on_geometry_dispose)
  self.lights_node.remove_event_listener("dispose", self.on_lights_node_dispose)
  match self._source_material {
    Some(m) => m.remove_event_listener("dispose", self.on_material_dispose)
    None => ()
  }
  match self.on_dispose {
    Some(f) => f()
    None => abort("TypeError: this.onDispose is not a function")
  }
}

///|
/// `node.getObjectAttribute( object )`.
fn _render_object_node_object_attribute(
  node : Node,
  object : @core.Object3D,
) -> @core.GeometryAttribute? {
  BufferAttributeNode::get_object_attribute(node, Object3D(object))
}
