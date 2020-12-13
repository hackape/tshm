module TSHM.Parser where

import           Control.Monad.Combinators.Expr (Operator (..), makeExprParser)
import           Data.Void                      ()
import           Prelude
import           TSHM.TypeScript
import           Text.Megaparsec                hiding (many, some)
import           Text.Megaparsec.Char
import qualified Text.Megaparsec.Char.Lexer     as L

type Parser = Parsec Void String

binary :: String -> (TsType -> TsType -> TsType) -> Operator Parser TsType
binary x f = InfixR $ f <$ string (" " <> x <> " ")

operators :: [[Operator Parser TsType]]
operators =
  [
    [ binary "&" (TsTypeExpression TsOperatorIntersection)
    , binary "|" (TsTypeExpression TsOperatorUnion)
    ]
  ]

pType :: Parser TsType
pType = makeExprParser expr operators
  where expr :: Parser TsType
        expr = try (pArraySpecial arrayables) <|> (TsTypeFunction <$> pFunction) <|> arrayables

        arrayables :: Parser TsType
        arrayables = choice
          [ TsTypeVoid <$ string "void"
          , TsTypeNull <$ string "null"
          , TsTypeUndefined <$ string "undefined"
          , TsTypeBoolean <$> ((True <$ string "true") <|> (False <$ string "false"))
          , TsTypeStringLiteral <$> pStringLiteral
          , TsTypeNumberLiteral <$> pNumberLiteral
          , TsTypeTuple <$> pTuple
          , TsTypeObject <$> pObject
          , try pGeneric
          , TsTypeMisc <$> some alphaNumChar
          ]

pGeneric :: Parser TsType
pGeneric = TsTypeGeneric <$> some alphaNumChar <*> pTypeArgs

pArraySpecial :: Parser TsType -> Parser TsType
pArraySpecial p = TsTypeGeneric "Array" . pure <$> p <* string "[]"

pStringLiteral :: Parser String
pStringLiteral = stringLiteral '\'' <|> stringLiteral '"'
  where stringLiteral :: Char -> Parser String
        stringLiteral c =
          let p = char c
           in p *> manyTill L.charLiteral p

pNumberLiteral :: Parser String
pNumberLiteral = (<>) . maybe "" pure <$> optional (char '-') <*> choice
  [ try $ (\x y z -> x <> pure y <> z) <$> some numberChar <*> char '.' <*> some numberChar
  , (:) <$> char '.' <*> some numberChar
  , some numberChar
  ]

pFunction :: Parser Function
pFunction = Function <$> optional pTypeArgs <*> pParams <*> pReturn

pTuple :: Parser [TsType]
pTuple = between (char '[') (char ']') $ sepBy pType (string ", ")

pObject :: Parser [(String, TsType)]
pObject = between (string "{ ") (string " }") (sepBy1 pPair (string ", ")) <|> [] <$ string "{}"
  where pPair :: Parser (String, TsType)
        pPair = (,) <$> some alphaNumChar <* string ": " <*> pType

pName :: Parser String
pName = optional (string "export ") *> string "declare const " *> some alphaNumChar <* string ": "

pTypeArgs :: Parser [TsType]
pTypeArgs = between (char '<') (char '>') (sepBy1 pTypeArg (string ", "))
  where pTypeArg :: Parser TsType
        pTypeArg = f <$> some alphaNumChar <*> optional pTypeArgs
        f x = \case
          Just y  -> TsTypeGeneric x y
          Nothing -> TsTypeMisc x

pParams :: Parser [TsType]
pParams = between (char '(') (char ')') $ sepBy pParam (string ", ")
  where pParam :: Parser TsType
        pParam = optional (string "...") *> some alphaNumChar *> string ": " *> optional (string "new ") *> pType

pReturn :: Parser TsType
pReturn = string " => " *> pType

pDeclaration :: Parser Declaration
pDeclaration = Declaration <$> pName <*> pType <* eof

